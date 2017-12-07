module webtank.net.deserialize_web_form;

import std.traits: isBoolean, isIntegral, isFloatingPoint, isSomeString, isArray, isAssociativeArray, ValueType;
import std.meta: Alias;
import std.typecons;
import std.datetime: Date, DateTime, SysTime, TimeOfDay;
import std.range: ElementType, chain;
import std.algorithm: filter, startsWith, skipOver, canFind, map, uniq;
import std.array: array;

import webtank.common.conv: conv;
import webtank.common.optional;
import webtank.common.optional_date;
import webtank.common.std_json.exception;
import webtank.net.web_form: FormData;

template isPlainType(T)
{
	enum bool isPlainType =
		isBoolean!T
		|| isIntegral!T
		|| isFloatingPoint!T
		|| isSomeString!T
		|| is( T == Date )
		|| is( T == DateTime )
		|| is( T == SysTime )
		|| is( T == TimeOfDay )
		|| is( T == OptionalDate );
}

template isPrimaryType(T) {
	enum bool isPrimaryType = isPlainType!T || isArray!T || isAssociativeArray!T;
}

auto convertPlainType(T)(string value)
{
	import std.algorithm: canFind;
	static if( isBoolean!T ) {
		return ["on", "true", "yes", "да"].canFind(value);
	}
	else static if( isIntegral!T || isFloatingPoint!T || isSomeString!T ) {
		return value.conv!T;
	} else static if( is( T == Date ) || is( T == DateTime ) || is( T == SysTime ) || is( T == TimeOfDay ) || is( T == OptionalDate ) ) {
		return T.fromISOExtString(value);
	} else {
		static assert(false, T.stringof ~ ` is not plain type!!!`);
	}
}

void setOfMaybeNull(string fieldName, StrucBase, T)(ref StrucBase result, auto ref T value)
{
	static if( isOptional!StrucBase ) {
		if( !result.isSet ) {
			result = OptionalValueType!(StrucBase)();
		}
	}
	__traits(getMember, result, fieldName) = value;
}

/** Автоматический перевод web-формы в структуру Struc */
void formDataToStruct(ResultBaseType, string subFieldDelim = "__", string arrayElemDelim = ",")(
	FormData formData, ref ResultBaseType result, string prefix = null)
{
	import std.algorithm: splitter;

	static if( isOptional!ResultBaseType ) {
		alias ResultType = OptionalValueType!ResultBaseType;
	} else {
		alias ResultType = ResultBaseType;
	}

	if( auto formFieldPtr = prefix in formData )
	{
		if( !isOptional!ResultBaseType || isSomeString!ResultType || (*formFieldPtr).length > 0 && (*formFieldPtr) != "null" )
		{
			static if( isPlainType!ResultType ) {
				result = convertPlainType!ResultType(*formFieldPtr);
			}
			else static if( isArray!ResultType )
			{
				alias Elem = ElementType!ResultType;
				static if( isPlainType!Elem ) {
					if( formData.array(prefix).length == 1 ) {
						result = splitter(*formFieldPtr, arrayElemDelim).map!( (it) => convertPlainType!Elem(it) )().array;
					} else {
						result = formData.array(prefix).conv!(Elem[]);
					}
				}
			}
		}
		else
		{
			static if( isOptional!ResultBaseType ) {
				result = null;
			}
		}
	}

	static if( is( ResultType == struct ) || isAssociativeArray!ResultType )
	{
		auto keyStart = chain(prefix, subFieldDelim);
		auto matchedKeys = formData.keys.filter!( (key) {
			return !prefix.length || key.startsWith(keyStart);
		})();
	}

	// Здесь нет else, чтобы можно было задать, например, дату как совокупность подполей так и целиком в виде строки формата ISO
	static if( is( ResultType == struct ) )
	{
		string[] thisLvlKeys = matchedKeys.map!( (key) {
			key.skipOver(keyStart);
			return key.splitter(subFieldDelim).front;
		}).uniq.array;

		foreach( structFieldName; __traits(allMembers, ResultType) )
		{
			static if(__traits(compiles, {
				__traits(getMember, result, structFieldName) = typeof(__traits(getMember, result, structFieldName)).init;
			})) {
				alias BaseFieldType = typeof(__traits(getMember, ResultType, structFieldName));
				static if( isOptional!BaseFieldType ) {
					alias FieldType = OptionalValueType!BaseFieldType;
				} else {
					alias FieldType = BaseFieldType;
				}

				if( thisLvlKeys.canFind(structFieldName) ) {
					BaseFieldType innerStruct;
					// Здесь может быть функция-свойство, а не простое поле, поэтому читаем значение, затем меняем
					// и снова записываем, чтобы изменить в структуре только те поля, которые надо
					static if( isOptional!ResultBaseType ) {
						if( result.isSet ) {
							innerStruct = __traits(getMember, result, structFieldName);
						}
					} else {
						innerStruct = __traits(getMember, result, structFieldName);
					}

					formDataToStruct(
						formData,
						innerStruct,
						(prefix.length? prefix ~ subFieldDelim: null) ~ structFieldName
					);
					setOfMaybeNull!structFieldName(result, innerStruct);
				}
			}
		}
	}
	else static if( isAssociativeArray!ResultType )
	{
		alias Value = ValueType!ResultType;
		Value[string] innerAA;
		foreach( key; matchedKeys )
		{
			key.skipOver(keyStart); // Skip prefix
			key = key.splitter(subFieldDelim).front; // Split AA key until next delimiter
			Value innerValue;
			static if( isOptional!ResultBaseType ) {
				if( result.isSet && key in result.value ) {
					innerValue = result.value[key];
				}
			} else {
				if( key in result ) {
					innerValue = result[key];
				}
			}
			formDataToStruct(formData, innerValue, prefix ~ subFieldDelim ~ key);
			innerAA[key] = innerValue;
		}
		result = innerAA;
	}
}

unittest
{
	import std.algorithm: equal;
	import webtank.common.optional_date;
	string[][string] rawData1 = [
		`boolParam`: [`true`],
		`intParam`: [`10`],
		`floatParam`: [`13.13`],
		`stringParam`: [`testParam`],
		`partDateParam__year`: [`2017`],
		`partDateParam__month`: [`8`],
		`partDateParam__day`: [`15`],
		`wholeDateParam`: [`2017-08-16`],
		`structParam__boolSub`: [`true`],
		`structParam__intSub`: [`-30`],
		`structParam__floatSub`: [`-30.3`],
		`structParam__stringSub`: [`trololo`],
		`structParam__partDateSub__year`: [`2018`],
		`structParam__partDateSub__month`: [`9`],
		`structParam__partDateSub__day`: [`20`],
		`structParam__wholeDateSub`: [`2019-10-23`],
		`datesAAParam__begin`: [`2019-10-23`],
		`datesAAParam__end`: [`2019-11-25`],
		`intArrayParam1`: [`5,4,3,2`],
		`intArrayParam2`: [`3`,`4`,`5`],
		`nullIntArrayParam`: [`null`],
		`optDateParam1`: [`2019-10-23`],
		`optDateParam2__day`: [`23`],
		`optDateParam2__month`: [`10`],
		`optDateParam2__year`: [`2019`],
		`optDateParam3`: [`null-10-null`],
		`optDateParam4`: [`null`]
	];
	FormData formData1 = new FormData(rawData1);
	static struct InternalStruct1
	{
		bool boolSub;
		int intSub;
		double floatSub;
		string stringSub;
	}

	static struct StructData1
	{
		bool boolParam;
		int intParam;
		double floatParam;
		string stringParam;
		Date partDateParam;
		Date wholeDateParam;
		InternalStruct1 structParam;
		Date[string] datesAAParam;
		int[] intArrayParam1;
		int[] intArrayParam2;
	}

	static struct StructData2
	{
		Optional!bool boolParam;
		Optional!int intParam;
		Optional!double floatParam;
		Optional!string stringParam;
		Optional!Date partDateParam;
		Optional!Date wholeDateParam;
		Optional!(int[]) emptyIntArrayParam;
		Optional!(int[]) nullIntArrayParam;
		Optional!InternalStruct1 structParam;
		OptionalDate optDateParam1;
		OptionalDate optDateParam2;
		OptionalDate optDateParam3;
		OptionalDate optDateParam4;
	}

	StructData1 strucData1;
	formDataToStruct(formData1, strucData1);
	assert(strucData1.boolParam == true);
	assert(strucData1.intParam == 10);
	assert(strucData1.floatParam == 13.13);
	assert(strucData1.stringParam == `testParam`);
	assert(strucData1.partDateParam.toISOExtString() == `2017-08-15`);
	assert(strucData1.wholeDateParam.toISOExtString() == `2017-08-16`);
	assert(strucData1.structParam.boolSub == true);
	assert(strucData1.structParam.intSub == -30);
	assert(strucData1.structParam.floatSub == -30.3);
	assert(strucData1.structParam.stringSub == `trololo`);
	assert(strucData1.datesAAParam[`begin`].toISOExtString() == `2019-10-23`);
	assert(strucData1.datesAAParam[`end`].toISOExtString() == `2019-11-25`);
	assert(equal(strucData1.intArrayParam1, [5,4,3,2]));
	assert(equal(strucData1.intArrayParam2, [3,4,5]));

	StructData2 structData2;
	formDataToStruct(formData1, structData2);
	assert(structData2.boolParam == true);
	assert(structData2.intParam == 10);
	assert(structData2.floatParam == 13.13);
	assert(structData2.stringParam == `testParam`);
	assert(structData2.partDateParam.toISOExtString() == `2017-08-15`);
	assert(structData2.wholeDateParam.toISOExtString() == `2017-08-16`);
	assert(structData2.emptyIntArrayParam.isNull);
	assert(!structData2.emptyIntArrayParam.isSet);
	assert(structData2.nullIntArrayParam.isNull);
	assert(!structData2.nullIntArrayParam.isSet);
	assert(structData2.structParam.intSub == -30);
	assert(structData2.structParam.floatSub == -30.3);
	assert(structData2.structParam.stringSub == `trololo`);
	assert(structData2.optDateParam1.toString() == `2019-10-23`);
	assert(structData2.optDateParam2.toString() == `2019-10-23`);
	assert(structData2.optDateParam3.year.isNull);
	assert(structData2.optDateParam3.month == 10);
	assert(structData2.optDateParam3.day.isNull);
	assert(structData2.optDateParam4.isNull);
}