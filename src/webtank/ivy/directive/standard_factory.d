module webtank.ivy.directive.standard_factory;

import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;

InterpreterDirectiveFactory makeStandardInterpreterDirFactory()
{
	import ivy.interpreter.directive.standard_factory: ivyFactory = makeStandardInterpreterDirFactory;
	import webtank.ivy.directive;

	auto factory = ivyFactory();
	factory.add(new OptStorageInterpreter);
	factory.add(new RemoteCallInterpreter);
	factory.add(new ToJSONBase64DirInterpreter);
	return factory;
}