module webtank.common.optional_date;

/++
$(LOCALE_EN_US
	Special date type that holds date components (year, month, day) in seperate fields, so each component of date is optional.
	It's designed to interface with standard std.datetime Date type
)

$(LOCALE_RU_RU
	Специальный тип даты, хранящий составляющие даты (год, месяц, день) в отдельных полях. При это каждая из компонент
	является необязательной. Разработано для взаимодействия со стандартным типом даты std.datetime Date
)
+/
struct OptionalDate
{
	import std.datetime: Date;
	import std.exception: enforceEx;
	import std.meta: AliasSeq;

	import webtank.common.optional: Optional, OptionalException;
private:
	Optional!short _year;
	Optional!ubyte _month;
	Optional!ubyte _day;

public:
	this(Date date)
	{
		_year = date.year;
		_month = date.month;
		_day = date.day;
	}

	alias YearTypeList = AliasSeq!(short, int, Optional!short, Optional!int, typeof(null));
	alias MonthOrDayTypeList = AliasSeq!(ubyte, int, Optional!ubyte, Optional!int, typeof(null));

	this(Y, M, D)(Y initYear, M initMmonth, D initDay)
	{
		enum bool isYearPred(Type) = is( Y == Type );
		enum bool isMonthPred(Type) = is( M == Type );
		enum bool isDayPred(Type) = is( D == Type );

		static if(
			anySatisfy!( isYearPred, YearTypeList ) &&
			anySatisfy!( isMonthPred, MonthOrDayTypeList ) &&
			anySatisfy!( isDayPred, MonthOrDayTypeList )
		) {
			this.year = initYear;
			this.month = initMmonth;
			this.day = initDay;
		}
		else
			static assert(0, `Unsupported ctor argument types for OptionalDate`);
	}

	Optional!short year() @property const {
		return _year;
	}

	void year(Optional!short value) @property {
		_year = value;
	}

	void year(Optional!int value) @property
	{
		if( value.isNull )
			_year = null;
		else
			_year = cast(short) value.value;
	}

	void year(int value) @property {
		_year = cast(short) value;
	}

	Optional!ubyte month() @property {
		return _month;
	}

	void month(Optional!ubyte value) @property {
		_month = value;
	}

	void month(Optional!int value) @property
	{
		if( value.isNull )
			_month = null;
		else
			_month = cast(ubyte) value.value;
	}

	void month(int value) @property {
		_month = cast(ubyte) value;
	}

	Optional!ubyte day() @property const {
		return _day;
	}

	void day(Optional!ubyte value) @property {
		_day = value;
	}

	void day(Optional!int value) @property
	{
		if( value.isNull )
			_day = null;
		else
			_day = cast(ubyte) value.value;
	}

	void day(int value) @property {
		_day = cast(ubyte) value;
	}

	bool isDefined() @property {
		return !_year.isNull && !_month.isNull && !_day.isNull;
	}

	bool isNull() @property {
		return _year.isNull && _month.isNull && _day.isNull;
	}

	Date get()
	{
		enforceEx!OptionalException(isDefined, "Attempt to get not fully defined date value of OptionalDate!!!");
		return Date(_year.value, _month.value, _day.value);
	}

	auto ref opAssign( RHS : Date )(auto ref RHS value) {
		this = OptionalDate(value);
	}

	auto ref opAssign( RHS : OptionalDate )(auto ref RHS value)
	{
		this._year = value._year;
		this._month = value._month;
		this._day = value._day;
	}

	auto ref opAssign( RHS : typeof(null) )( RHS value )
		/+pure @safe nothrow+/
	{
		_year = null;
		_month = null;
		_day = null;
		return this;
	}

	string toString()
	{
		return ( _year.isNull ? "null" : _year.toString() ) ~ `-`
			~ ( _month.isNull ? "null" : _month.toString() ) ~ `-`
			~ ( _day.isNull ? "null" : _day.toString() );
	}

	static OptionalDate fromISOExtString(string value)
	{
		import std.algorithm: splitter;
		import std.conv: to;
		OptionalDate result;
		if( !value.length || value == "null" ) {
			return result;
		}

		auto spl = value.splitter("-");
		foreach( i; 0..3 )
		{
			assert(!spl.empty);
			if( !spl.front.length || spl.front == "null" )
			{
				switch( i )
				{
					case 0: result._year = null; break;
					case 1: result._month = null; break;
					case 2: result._day = null; break;
					default: break;
				}
			} else {
				switch( i )
				{
					case 0: result._year = spl.front.to!short; break;
					case 1: result._month = spl.front.to!ubyte; break;
					case 2: result._day = spl.front.to!ubyte; break;
					default: break;
				}
			}
			spl.popFront();
		}
		assert(spl.empty);
		return result;
	}
}
