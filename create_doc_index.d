module create_doc_index;

void main()
{
	import std.file: dirEntries, write, SpanMode, getcwd;
	import std.algorithm: filter, map, endsWith, sort;
	import std.array: join, array;
	import std.path: relativePath, buildPath, stripExtension;
	
	immutable sourcePath = "src/webtank";
	string index = dirEntries(sourcePath, SpanMode.depth)
		.filter!(f => f.name.endsWith(".d")).array
		.sort()
		.map!((f) {
			string relRef = buildPath(getcwd(), f).relativePath(buildPath(getcwd(), sourcePath));
			return `			<li><a href="` ~ relRef.stripExtension() ~ `.html">` ~ relRef ~ `</a></li>`;
		})
		.join("\r\n");
	
	write(
		sourcePath ~ "/index.d",
`/++
	$(LANG_EN Index of modules)
	$(LANG_RU Оглавление)

	See_Also:
		<ul>
` ~ index ~ `
		</ul>
+/

module index;
void helloWorld() {} /// helloWorld fake method
`	);
}
