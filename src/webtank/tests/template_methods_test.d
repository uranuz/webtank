import std.stdio, std.conv, std.variant;


interface IBaseRecord
{
	
	
}


class Record: IBaseRecord
{
protected:
	double num;
	
public:
	
	this() {}
	
	this(double val)
	{
		num = val;
	}
	
	string get(string fieldName)()
	{
		assert( typeid(this) == typeid(typeof(this)), "Wrong type!" );
		
		return num.to!string;
	}
	
}


class DerivedRecord1: Record
{
protected:
	string str;
	
public:
	
	this(string val)
	{
		str = val;
	}
	
	string get(string fieldName)()
	{
		assert( typeid(this) == typeid(typeof(this)), "Wrong type!" );
		
		return str;
	}
	
}


class DerivedRecord2: Record
{
protected:
	int num;
	
public:
	
	this(int val)
	{
		num = val;
	}
	
	string get(string fieldName)()
	{
		assert( typeid(this) == typeid(typeof(this)), "Wrong type!" );
		
		return num.to!string;
	}	
	
}


void main()
{
	DerivedRecord2 rec1 = new DerivedRecord2(666);
	Record rec2 = rec1;
	
	writeln( rec2.get!("name")() );
	
}
