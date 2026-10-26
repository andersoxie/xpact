/* Uses Jenkins' installed Declarative parser; never evaluates a Pipeline or sends mail.
 * Offline extension metadata is partial: controller-specific step/argument validation,
 * plugin validator contributors, SCM, CPS execution and SMTP delivery are not tested.
 */
import org.jenkinsci.plugins.pipeline.modeldefinition.parser.Converter
import org.jenkinsci.plugins.pipeline.modeldefinition.DescriptorLookupCache
import org.jenkinsci.plugins.pipeline.modeldefinition.agent.DeclarativeAgentDescriptor
import org.jenkinsci.plugins.pipeline.modeldefinition.agent.impl.Any
import org.jenkinsci.plugins.pipeline.modeldefinition.agent.impl.None
import org.jenkinsci.plugins.pipeline.modeldefinition.agent.impl.Label
import org.jenkinsci.plugins.pipeline.modeldefinition.model.Parameters
import org.jenkinsci.plugins.pipeline.modeldefinition.model.Options
import org.jenkinsci.plugins.structs.SymbolLookup
import org.jenkinsci.plugins.structs.describable.DescribableModel
import hudson.model.StringParameterDefinition
import hudson.model.BooleanParameterDefinition
import jenkins.model.BuildDiscarderProperty
import hudson.plugins.timestamper.pipeline.TimestamperStep
import org.jenkinsci.Symbol
import org.codehaus.groovy.control.MultipleCompilationErrorsException
import org.codehaus.groovy.control.CompilationUnit

// A separate JVM has no running Jenkins ExtensionList containing this cache.
// Keep its actual implementation and change only the process-local cache accessor.
def offlineCache = new DescriptorLookupCache()
DescriptorLookupCache.metaClass.'static'.getPublicCache = { -> offlineCache }

// Populate only metadata consumed by these Jenkinsfiles from the installed types.
// The real ModelParser and ModelValidatorImpl still reject invalid declarations.
Map agentModels = [:]
[[type: Any, descriptor: Any.DescriptorImpl], [type: None, descriptor: None.DescriptorImpl],
 [type: Label, descriptor: Label.DescriptorImpl]].each { entry ->
    entry.descriptor.getAnnotation(Symbol).value().each { name ->
        agentModels[name] = new DescribableModel(entry.type)
    }
}
DeclarativeAgentDescriptor.metaClass.'static'.getDescribableModels = { -> agentModels }
DeclarativeAgentDescriptor.metaClass.'static'.zeroArgModels = { ->
    agentModels.findAll { name, model -> model.parameters.empty }
}
DeclarativeAgentDescriptor.metaClass.'static'.allSorted = { ->
    agentModels.keySet().sort().collect { [name: it] }
}
Map allowedParameterSymbols = [:]
[new StringParameterDefinition.DescriptorImpl(), new BooleanParameterDefinition.DescriptorImpl()].each { descriptor ->
    SymbolLookup.getSymbolValue(descriptor).each { name -> allowedParameterSymbols[name] = descriptor.id }
}
Parameters.metaClass.'static'.getAllowedParameterTypes = { -> allowedParameterSymbols }
Map optionTypes = [:]
def discarder = new BuildDiscarderProperty.DescriptorImpl()
SymbolLookup.getSymbolValue(discarder).each { name -> optionTypes[name] = discarder.id }
def timestamps = new TimestamperStep.DescriptorImpl()
optionTypes[timestamps.functionName] = timestamps.id
Options.metaClass.'static'.getAllowedOptionTypes = { -> optionTypes }

def parseDeclarative(String source) {
    // Converter.scriptToPipelineDef obtains its loader from a running Jenkins instance.
    // Supply the installed libraries directly, while retaining its real parser/validator.
    def loader = new GroovyClassLoader(Converter.class.classLoader)
    def unit = new CompilationUnit(Converter.makeCompilerConfiguration(), null, loader)
    unit.addSource(Converter.PIPELINE_SCRIPT_NAME, source)
    Converter.compilationUnitToPipelineDef(unit)
}

String original = '''pipeline {
  agent none
  parameters {
    string(name: 'EMAIL_RECIPIENTS', defaultValue: (params.EMAIL_RECIPIENTS ?: '').trim(), trim: true)
  }
  stages { stage('Validation fixture') { steps { echo 'never executed' } } }
}'''

try {
    parseDeclarative(original)
    assert false: 'The original method-call parameter default unexpectedly passed Declarative validation'
} catch (MultipleCompilationErrorsException failure) {
    assert failure.message.contains('Expected a symbol'): failure.message
    println 'PASS regression: real Declarative parser rejects the original method-call default'
}

String corrected = original.replace("(params.EMAIL_RECIPIENTS ?: '').trim()",
                                    '\"${(params.EMAIL_RECIPIENTS ?: \'\').trim()}\"')
assert parseDeclarative(corrected) != null
println 'PASS regression: real Declarative parser accepts the quoted GString default'

try {
    parseDeclarative(corrected.replace('string(name:', 'unknownParameterType(name:'))
    assert false: 'An unknown parameter type unexpectedly passed model validation'
} catch (MultipleCompilationErrorsException failure) {
    assert failure.message.contains('Invalid parameter type'): failure.message
    println 'PASS metadata: real model validator rejects an unknown parameter type'
}

List<String> paths = args ? args.toList() : ['ci/Jenkinsfile.windows-phase1', 'ci/Jenkinsfile.all-tests']
paths.each { String path ->
    File source = new File(path)
    assert source.isFile(): "Missing Jenkinsfile: ${source}"
    try {
        assert parseDeclarative(source.getText('UTF-8')) != null
    } catch (MultipleCompilationErrorsException failure) {
        System.err.println("FAIL ${path}: ${failure.message}")
        System.exit(1)
    }
    println "PASS Declarative validation: ${path}"
}
println 'Offline Declarative parser/model validation passed; controller-specific validation remains untested.'
println 'No Pipeline steps were executed.'
