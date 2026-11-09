/* Exercises the real Jenkinsfile helpers with build-scoped, in-memory stashes. */
import org.codehaus.groovy.runtime.InvokerHelper

class PlotReportFixture {
    final Map env = [BUILD_TAG: 'jenkins-xpact-123', BUILD_NUMBER: '123',
                     BUILD_URL: 'https://jenkins.invalid/job/xpact/123/']
    final Map params = [RUN_BENCHMARKS: true, RUN_WSL_EIFFEL_BENCHMARKS: true,
                        RUN_LARGE_XML_BENCHMARKS: true, LARGE_XML_FILE: 'fixture.xml']
    final Map currentBuild = [:]
    final Map files = [:]
    final Map stashes = [:]
    final List publications = []
    final List archives = []
    final List rendered = []
    final List renderSettings = []
    int junitPublications = 0
    String directory = ''
    String failCapture
    String failStash
    boolean failRender
    boolean failPreparation
    def script

    PlotReportFixture(Class pipelineClass) {
        files['scripts/jenkins_plot_report.py'] = 'report tool'
        files['scripts/dual_jenkins_reports.py'] = 'dual report tool'
        Binding binding = new Binding([
            env: env, params: params, currentBuild: currentBuild,
            pipeline: { Closure ignored -> },
            stash: { Map args -> saveStash(args) },
            unstash: { String name -> restoreStash(name) },
            fileExists: { String path -> files.containsKey(resolve(path)) },
            withEnv: { List entries, Closure body -> withEnvironment(entries, body) },
            dir: { String path, Closure body -> inDirectory(path, body) },
            deleteDir: { -> clearDirectory() },
            powershell: { String body -> powershell(body) },
            archiveArtifacts: { Map args -> archives << args },
            publishHTML: { Map args -> publications << args.target },
            junit: { Map ignored -> junitPublications++ },
            echo: { Object ignored -> },
        ])
        script = InvokerHelper.createScript(pipelineClass, binding)
        script.run()
    }

    String resolve(String path) { directory ? "${directory}/${path}".toString() : path }

    void saveStash(Map args) {
        if (args.name == failStash) { throw new IOException('simulated stash persistence failure') }
        Map saved = [:]
        args.includes.split(',').each { String path ->
            assert files.containsKey(resolve(path)): "Missing stash input ${resolve(path)}"
            saved[path] = files[resolve(path)]
        }
        assert saved
        stashes[args.name.toString()] = saved
    }

    void restoreStash(String name) {
        assert stashes.containsKey(name): "Unowned stash ${name}"
        stashes[name].each { path, value -> files[resolve(path)] = value }
    }

    void inDirectory(String path, Closure body) {
        String previous = directory
        directory = resolve(path)
        try { body.call() } finally { directory = previous }
    }

    void clearDirectory() {
        assert directory.startsWith('build/plot-report-assembly-123-')
        files.keySet().findAll { it.startsWith(directory + '/') }.each { files.remove(it) }
    }

    void withEnvironment(List entries, Closure body) {
        Map before = new LinkedHashMap(env)
        entries.each { entry ->
            def parts = entry.toString().split('=', 2)
            env[parts[0]] = parts[1]
        }
        try { body.call() } finally { env.clear(); env.putAll(before) }
    }

    void powershell(String body) {
        if (body.contains('$CaptureArgs')) {
            if (env.REPORT_LANE == failCapture) { throw new IOException('simulated capture failure') }
            files["build/jenkins-plot-snapshots/${env.REPORT_LANE}.json".toString()] =
                "${env.BUILD_TAG}:${env.REPORT_LANE}".toString()
        } else if (body.contains('$RenderArgs')) {
            if (failRender) { throw new IOException('simulated render failure') }
            String prefix = "${env.REPORT_ASSEMBLY}/build/jenkins-plot-snapshots/"
            rendered << files.findAll { path, value -> path.startsWith(prefix) }.values().sort()
            renderSettings << new LinkedHashMap(env)
            files['build/all-benchmark-plots/index.html'] = 'consolidated current report'
        } else if (body.contains('$SnapshotPath')) {
            files.remove("build/jenkins-plot-snapshots/${env.REPORT_LANE}.json".toString())
        } else {
            assert body.contains('$PLOT_CURRENT_TSV') || body.contains('$env:PLOT_CURRENT_TSV')
            if (failPreparation) { throw new IOException('simulated stale-input removal failure') }
        }
    }

    void capture(String lane) {
        String manifest = "${lane}-manifest.tsv"
        files[manifest] = 'current manifest'
        script.capturePlotReport(lane, "build/${lane}", manifest)
    }
}

File root = new File(args ? args[0] : '.').canonicalFile
int checks = 0
['windows-phase1', 'all-tests'].each { String name ->
    Class pipelineClass = new GroovyClassLoader().parseClass(new File(root, "ci/Jenkinsfile.${name}"))

    def run = new PlotReportFixture(pipelineClass)
    run.script.initializePlotReport()
    run.capture('dual')
    run.files.clear() // all-tests starts later stages with deleteDir().
    run.capture('windows')
    run.files.clear()
    run.capture('wsl')
    run.files.clear()
    run.script.publishAllBenchmarkPlots()
    assert run.rendered.last() == ['jenkins-xpact-123:dual', 'jenkins-xpact-123:windows', 'jenkins-xpact-123:wsl']
    assert run.publications*.reportName == ['All Benchmark Plots']
    assert run.archives*.artifacts == ['build/all-benchmark-plots/index.html']
    assert run.currentBuild.description.contains('/artifact/build/all-benchmark-plots/index.html')
    assert !run.files.keySet().any { it.startsWith('build/plot-report-assembly-') }
    checks++

    ['capture', 'stash'].each { String failingBoundary ->
        run = new PlotReportFixture(pipelineClass)
        run.script.initializePlotReport()
        run.capture('windows')
        if (failingBoundary == 'capture') { run.failCapture = 'windows' }
        else { run.failStash = 'xpact-plot-report-windows' }
        try { run.capture('windows'); assert false } catch (IOException expected) { }
        assert !run.env.PLOT_REPORT_WINDOWS
        run.files.clear()
        run.script.publishAllBenchmarkPlots()
        assert run.rendered.last().empty // The earlier successful snapshot must not reappear.
        run.failCapture = null
        run.failStash = null
        run.capture('windows')
        run.files.clear()
        run.script.publishAllBenchmarkPlots()
        assert run.rendered.last() == ['jenkins-xpact-123:windows']
        checks++
    }

    run = new PlotReportFixture(pipelineClass)
    run.script.initializePlotReport()
    run.params.RUN_BENCHMARKS = false
    run.params.RUN_WSL_EIFFEL_BENCHMARKS = false
    run.params.LARGE_XML_FILE = ''
    run.files.clear()
    run.script.publishAllBenchmarkPlots()
    assert run.rendered.last().empty
    assert run.renderSettings.last().REPORT_DISABLED == 'dual,windows,wsl,large'
    checks++

    run = new PlotReportFixture(pipelineClass)
    run.script.initializePlotReport()
    run.capture('windows')
    run.failRender = true
    try { run.script.publishAllBenchmarkPlots(); assert false } catch (IOException expected) { }
    assert run.publications.empty
    assert run.archives.empty
    assert !run.currentBuild.description
    assert !run.files.keySet().any { it.startsWith('build/plot-report-assembly-') }
    checks++

    run = new PlotReportFixture(pipelineClass)
    run.script.initializePlotReport()
    run.capture('windows')
    run.env.BUILD_TAG = 'jenkins-xpact-124'
    run.script.publishAllBenchmarkPlots()
    assert run.rendered.empty
    run.script.initializePlotReport()
    run.files.clear()
    run.script.publishAllBenchmarkPlots()
    assert run.rendered.last().empty
    checks++

    run = new PlotReportFixture(pipelineClass)
    run.script.initializePlotReport()
    run.script.prepareBenchmarkPlotSource('windows', 'build/benchmarks/benchmark-results.tsv', 'same-machine-benchmarks')
    assert run.env.PLOT_INPUT_WINDOWS == run.env.BUILD_TAG
    run.capture('windows')
    run.failPreparation = true
    try {
        run.script.prepareBenchmarkPlotSource('windows', 'build/benchmarks/benchmark-results.tsv', 'same-machine-benchmarks')
        assert false
    } catch (IOException expected) { }
    assert !run.env.PLOT_INPUT_WINDOWS
    assert !run.env.PLOT_REPORT_WINDOWS
    run.files.clear()
    run.script.publishAllBenchmarkPlots()
    assert run.rendered.last().empty
    checks++

    println "PASS ${name}: build ownership, workspace clearing, failed capture/stash, retry, disabled lanes and render failure"

    run = new PlotReportFixture(pipelineClass)
    run.script.metaClass.writeBenchmarkJUnitReport = { String path, String suite, String prefix -> }
    run.script.metaClass.writeBenchmarkPlotCsvFiles = { String path, String prefix, String group -> [] }
    run.script.metaClass.publishBenchmarkPlots = { Object ignored -> }
    run.script.metaClass.publishJenkinsTestResults = { -> run.junitPublications++ }
    run.script.initializePlotReport()
    run.env.PLOT_INPUT_WINDOWS = run.env.BUILD_TAG
    run.files['jenkins-plot-same-machine-benchmarks-manifest.tsv'] = 'current manifest'
    run.failStash = 'xpact-plot-report-windows'
    try {
        run.script.publishBenchmarkFamily('windows', 'build/benchmarks', 'benchmark-results.tsv',
                                          'same-machine-benchmarks', 'Benchmark Trends', 'test suite')
        assert false
    } catch (IOException expected) { }
    assert run.archives.size() == 1
    assert run.archives.first().artifacts.contains('build/benchmarks/*.tsv')
    assert run.junitPublications == 2
    assert !run.env.PLOT_REPORT_WINDOWS
    assert !run.files.containsKey('build/jenkins-plot-snapshots/windows.json')
    checks++
}
println "${checks} plot publication scenarios passed; no Jenkins service was contacted."
