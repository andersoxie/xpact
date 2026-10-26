/* Runs the real Jenkinsfiles with an in-memory Pipeline DSL. No Jenkins or SMTP calls. */
import org.codehaus.groovy.runtime.InvokerHelper

class SimulatedBuildInterruption extends InterruptedException {}

class PipelineEmailFixture {
    final Map params
    final Map currentBuild = [currentResult: 'FAILURE', result: 'FAILURE']
    final Map env = [JOB_NAME: 'xpact', BUILD_NUMBER: '123',
                     BUILD_URL: 'http://jenkins.invalid/job/xpact/123/']
    final Map parameterDefinitions = [:]
    final Map postActions = [always: [], cleanup: []]
    final List mails = []
    final List catchOptions = []
    final List handledFailures = []
    final List warnings = []
    final List events = []
    Throwable mailFailure
    Throwable archiveFailure

    PipelineEmailFixture(Class pipelineClass, Map submitted = [:]) {
        params = new LinkedHashMap(submitted)
        Binding binding = new Binding([
            params: params, currentBuild: currentBuild, env: env, none: 'none',
            pipeline: { Closure body -> evaluate(body, this) },
            mail: { Map arguments ->
                events << 'mail'
                mails << new LinkedHashMap(arguments)
                if (mailFailure != null) { throw mailFailure }
            },
            catchError: { Map options, Closure body -> catchBuildError(options, body) },
            echo: { Object message -> warnings << message.toString() },
        ])
        InvokerHelper.createScript(pipelineClass, binding).run()
    }

    static void evaluate(Closure body, Object target) {
        body.delegate = target
        body.resolveStrategy = Closure.DELEGATE_FIRST
        body.call()
    }

    void agent(Object ignored) {}
    void options(Closure ignored) {}
    void environment(Closure ignored) {}
    void stages(Closure ignored) {}
    void parameters(Closure body) { evaluate(body, new ParameterRecorder(this)) }
    void post(Closure body) { evaluate(body, new PostRecorder(this)) }
    void script(Closure body) { body.call() }

    void archiveArtifacts(Map ignored) {
        events << 'archive'
        if (archiveFailure != null) { throw archiveFailure }
    }

    void catchBuildError(Map options, Closure body) {
        catchOptions << new LinkedHashMap(options)
        try {
            body.call()
        } catch (Exception failure) {
            if (failure instanceof InterruptedException && options.catchInterruptions == false) {
                throw failure
            }
            handledFailures << failure
            warnings << (options.message ?: failure.message).toString()
            // Jenkins results can only become worse; SUCCESS preserves an existing failure.
            List results = ['SUCCESS', 'UNSTABLE', 'FAILURE', 'NOT_BUILT', 'ABORTED']
            String proposed = options.containsKey('buildResult') ? options.buildResult : 'FAILURE'
            if (proposed != null && results.indexOf(proposed) > results.indexOf(currentBuild.currentResult)) {
                setResult(proposed)
            }
        }
    }

    void setResult(String result) {
        currentBuild.currentResult = result
        currentBuild.result = result
    }

    void finishBuild() {
        try {
            postActions.always.each { Closure body -> evaluate(body, this) }
        } catch (Exception ignored) {
            setResult('FAILURE')
        } finally {
            postActions.cleanup.each { Closure body -> evaluate(body, this) }
        }
    }
}

class ParameterRecorder {
    final PipelineEmailFixture fixture
    ParameterRecorder(PipelineEmailFixture fixture) { this.fixture = fixture }
    void string(Map definition) {
        assert !fixture.parameterDefinitions.containsKey(definition.name): "Duplicate parameter ${definition.name}"
        fixture.parameterDefinitions[definition.name] = definition
    }
    void booleanParam(Map ignored) {}
}

class PostRecorder {
    final PipelineEmailFixture fixture
    PostRecorder(PipelineEmailFixture fixture) { this.fixture = fixture }
    void always(Closure body) { fixture.postActions.always << body }
    void cleanup(Closure body) { fixture.postActions.cleanup << body }
}

File repository = new File(args ? args[0] : '.').canonicalFile
int scenarios = 0
Closure check = { String label, Closure body ->
    body.call()
    scenarios++
    println "PASS ${label}"
}

['Jenkinsfile.windows-phase1', 'Jenkinsfile.all-tests'].each { String name ->
    File source = new File(repository, "ci/${name}")
    Class pipelineClass = new GroovyClassLoader().parseClass(source)
    Closure fixture = { Map submitted = [:] -> new PipelineEmailFixture(pipelineClass, submitted) }

    check("${name}: recipient defaults retain a submitted value and support clearing") {
        [[:], [EMAIL_RECIPIENTS: null], [EMAIL_RECIPIENTS: ''],
         [EMAIL_RECIPIENTS: '  \t '],
         [EMAIL_RECIPIENTS: '  first@example.invalid, second@example.invalid  ']].each { Map submitted ->
            def run = fixture(submitted)
            Map definition = run.parameterDefinitions.EMAIL_RECIPIENTS
            assert definition != null
            assert definition.defaultValue == (submitted.EMAIL_RECIPIENTS ?: '').trim()
            assert definition.trim == true
            assert run.postActions.cleanup.size() == 1
        }
        String previous = fixture([EMAIL_RECIPIENTS: ' first@example.invalid '])
            .parameterDefinitions.EMAIL_RECIPIENTS.defaultValue
        assert fixture([EMAIL_RECIPIENTS: previous]).parameterDefinitions.EMAIL_RECIPIENTS.defaultValue == previous
        assert fixture([EMAIL_RECIPIENTS: '']).parameterDefinitions.EMAIL_RECIPIENTS.defaultValue == ''
    }

    check("${name}: missing, null, empty and whitespace recipients suppress email") {
        [[:], [EMAIL_RECIPIENTS: null], [EMAIL_RECIPIENTS: ''], [EMAIL_RECIPIENTS: ' \t\n ']].each { Map submitted ->
            ['FAILURE', 'UNSTABLE'].each { String result ->
                def run = fixture(submitted)
                run.setResult(result)
                run.finishBuild()
                assert run.mails.empty
                assert run.catchOptions.empty
                assert run.currentBuild.currentResult == result
            }
        }
    }

    ['FAILURE', 'UNSTABLE'].each { String result ->
        check("${name}: ${result} sends one email with build and console links") {
            def run = fixture([EMAIL_RECIPIENTS: ' first@example.invalid, second@example.invalid '])
            run.setResult(result)
            run.finishBuild()
            assert run.mails.size() == 1
            Map message = run.mails.first()
            assert message.to == 'first@example.invalid, second@example.invalid'
            assert message.subject.toString() == "xpact #123: ${result}"
            assert message.body.toString().contains(result)
            assert message.body.toString().contains(run.env.BUILD_URL)
            assert message.body.toString().contains(run.env.BUILD_URL + 'console')
            assert !message.containsKey('attachmentsPattern')
            assert !message.containsKey('attachLog')
            assert run.catchOptions.size() == 1
            assert run.catchOptions.first().buildResult == 'SUCCESS'
            assert run.catchOptions.first().stageResult == 'SUCCESS'
            assert run.catchOptions.first().catchInterruptions == false
            assert run.currentBuild.currentResult == result
            if (name == 'Jenkinsfile.windows-phase1') {
                assert run.events.indexOf('archive') < run.events.indexOf('mail')
            }
        }

        check("${name}: SMTP failure preserves ${result}") {
            def run = fixture([EMAIL_RECIPIENTS: 'first@example.invalid'])
            run.setResult(result)
            run.mailFailure = new IOException('simulated SMTP outage')
            run.finishBuild()
            assert run.mails.size() == 1
            assert run.warnings.size() == 1
            assert run.currentBuild.currentResult == result
            assert run.currentBuild.result == result
        }
    }

    check("${name}: successful, aborted and unbuilt runs do not send") {
        ['SUCCESS', 'ABORTED', 'NOT_BUILT'].each { String result ->
            def run = fixture([EMAIL_RECIPIENTS: 'first@example.invalid'])
            run.setResult(result)
            run.finishBuild()
            assert run.mails.empty
            assert run.catchOptions.empty
            assert run.currentBuild.currentResult == result
        }
    }

    check("${name}: build interruption propagates through email failure handling") {
        def run = fixture([EMAIL_RECIPIENTS: 'first@example.invalid'])
        run.setResult('UNSTABLE')
        def interruption = new SimulatedBuildInterruption()
        run.mailFailure = interruption
        try {
            run.finishBuild()
            assert false: 'Build interruption was swallowed'
        } catch (SimulatedBuildInterruption caught) {
            assert caught.is(interruption)
        }
        assert run.mails.size() == 1
        assert run.warnings.empty
        assert run.catchOptions.first().catchInterruptions == false
    }

    check("${name}: successive build results and recipient changes do not leak state") {
        def run = fixture([EMAIL_RECIPIENTS: 'first@example.invalid'])
        run.mailFailure = new IOException('simulated first-build SMTP outage')
        [['FAILURE', 'first@example.invalid', 1], ['SUCCESS', 'first@example.invalid', 0],
         ['UNSTABLE', 'second@example.invalid', 1], ['ABORTED', 'second@example.invalid', 0],
         ['FAILURE', '', 0], ['UNSTABLE', ' third@example.invalid ', 1]].each { List step ->
            int sentBefore = run.mails.size()
            run.setResult(step[0])
            run.params.EMAIL_RECIPIENTS = step[1]
            run.finishBuild()
            assert run.mails.size() - sentBefore == step[2]
            if (step[2]) { assert run.mails.last().to == step[1].trim() }
            assert run.currentBuild.currentResult == step[0]
            run.mailFailure = null
        }
        assert run.handledFailures.size() == 1
    }

    if (name == 'Jenkinsfile.windows-phase1') {
        check("${name}: archive failure is visible to the final notification") {
            def run = fixture([EMAIL_RECIPIENTS: 'first@example.invalid'])
            run.setResult('SUCCESS')
            run.archiveFailure = new IOException('simulated artifact archive failure')
            run.finishBuild()
            assert run.currentBuild.currentResult == 'FAILURE'
            assert run.mails.size() == 1
            assert run.mails.first().subject.toString().endsWith(': FAILURE')
            assert run.events == ['archive', 'mail']
        }
    }
}

println "${scenarios} email notification scenarios passed; no email was sent."
