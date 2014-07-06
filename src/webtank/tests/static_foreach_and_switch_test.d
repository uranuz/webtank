import std.stdio, std.typetuple, std.typecons, std.conv;





void main()
{
	static immutable tp = tuple("Vasya", true, "Petya"d, 10.333, 100500);
	
	string[] arr;
	
	size_t num = 4;
	
	theswitch:
	switch(num)
	{
	
		foreach( i, el; tp )
		{
			case i:
				arr ~= el.to!string;
			break;
		}
		break;
		default:
			writeln("default");
		break;
	}
	
	writeln(arr);
	
} 
