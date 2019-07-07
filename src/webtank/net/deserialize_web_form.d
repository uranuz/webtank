module webtank.net.deserialize_web_form;

import std.traits: isBoolean, isIntegral, isFloatingPoint, isSomeString, isArray, isAssociativeArray, ValueType;
import std.meta: Alias;
import std.typecons;
import std.datetime: Date, DateTime, SysTime, TimeOfDay;
import std.range: ElementType, chain;
import std.algorithm: filter, startsWith, skipOver, canFind, map, uniq;
import std.array: array;
import std.exception: ifThrown;

import webtank.common.conv: conv;
import webtank.common.optional;
import webtank.common.optional_date;
import webtank.common.std_json.exception;
import webtank.net.web_form: FormData, IFormData;

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

void setOfMaybeNull(string fieldName, StrucBase, T)(ref StrucBase result, ref T value)
{
	static if( isUndefable!StrucBase ) {
		// Если сюда попали, то какие-то поля структуры уже должны присутствовать, но они все могут быть null
		// для Undefable в этому случае нужно явно установить в null
		if( result.isUndef ) {
			result = null;
		}
	}

	static if( isUndefable!T ) {
		if( value.isUndef )
			return;
	} else static if( isOptional!T ) {
		if( value.isNull )
			return;
	}

	static if( isOptional!StrucBase ) {
		// Нужно проинициализировать перед установкой поля, чтобы не получить ошибку
		if( !result.isSet ) {
			result = OptionalValueType!(StrucBase)();
		}
	}

	__traits(getMember, result, fieldName) = value;
}

/** Автоматический перевод web-формы в структуру Struc */
void formDataToStruct(ResultBaseType, DictType, string subFieldDelim = "__", string arrayElemDelim = ",")(
	DictType formData, ref ResultBaseType result, string prefix = null)
{
	import std.algorithm: splitter;
	import std.json;
	import webtank.common.std_json.from;
	import std.conv: ConvException;

	static if( isOptional!ResultBaseType ) {
		alias ResultType = OptionalValueType!ResultBaseType;
	} else {
		alias ResultType = ResultBaseType;
	}

	if( auto formFieldPtr = prefix in formData )
	{
		if(
			isSomeString!ResultType // All values allowed for string type
			|| (!isSomeString!ResultType && (*formFieldPtr).length > 0 && (*formFieldPtr) != "null") // Empty string or null is treated as isNull for Optional
			|| isArray!ResultType && (
					formData.array(prefix).length > 1
					|| formData.array(prefix).length == 1 && (*formFieldPtr).length > 0 && (*formFieldPtr) != "null"
			) // Non empty arrays are treated as non null
		) {
			static if( isPlainType!ResultType ) {
				try {
					result = convertPlainType!ResultType(*formFieldPtr);
				} catch(ConvException ex) {
					throw new ConvException(`Error while extracting form field: ` ~ prefix ~ `. Error msg: ` ~ ex.msg);
				}
			}
			else static if( isArray!ResultType )
			{
				ResultType arrayResult;
				foreach( ref item; formData.array(prefix) )
				{
					JSONValue jData = parseJSON(item).ifThrown!JSONException(JSONValue());
					if( jData.type == JSONType.array ) {
						arrayResult ~= fromStdJSON!ResultType(jData);
					} else {
						alias Elem = ElementType!ResultType;
						static assert(!isOptional!(Elem), `TODO: Handling of this is not supported yet! Сорян, чувак!`);
						static if( isPlainType!Elem ) {
							if(
								isSomeString!Elem
								|| (!isSomeString!Elem && item.length > 0 && item != "null")
							) {
								arrayResult ~= splitter(item, arrayElemDelim).map!( (it) {
									try {
										return convertPlainType!Elem(it);
									} catch(ConvException ex) {
										throw new ConvException(`Error while extracting form field array item: ` ~ prefix ~ `. Error msg: ` ~ ex.msg);
									}
								})().array;
							}
						}
					}
				}
				result = arrayResult;
			}
		} else static if( isOptional!ResultBaseType ) {
			result = null; // Если у нас Undefable, то должны явно задать null, если поле есть, но пустое
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
					// Принудительно делаем Optional, либо Undefable, чтобы не получить значение по умолчанию вместо null
					static if( isUndefable!BaseFieldType ) {
						Undefable!FieldType innerStruct;
					} else {
						Optional!FieldType innerStruct;
					}

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
		`emptyBoolParam`: [``],
		`emptyIntParam`: [``],
		`emptyFloatParam`: [``],
		`emptyStringParam`: [``],
		`partDateParam__year`: [`2017`],
		`partDateParam__month`: [`8`],
		`partDateParam__day`: [`15`],
		`wholeDateParam`: [`2017-08-16`],
		`emptyDateParam__day`: [``],
		`emptyDateParam__month`: [``],
		`emptyDateParam__year`: [``],
		`optEmptyDateParam__day`: [``],
		`optEmptyDateParam__month`: [``],
		`optEmptyDateParam__year`: [``],
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
		`emptyIntArrayParam`: [``],
		`nullIntArrayParam`: [`null`],
		`optDateParam1`: [`2019-10-23`],
		`optDateParam2__day`: [`23`],
		`optDateParam2__month`: [`10`],
		`optDateParam2__year`: [`2019`],
		`optDateParam3`: [`null-10-null`],
		`optDateParam4`: [`null`],
		`jsonIntArray`: [`[1, 2, 3]`],
		`jsonStringArray`: [`["may", "jun", "jul"]`],
		`json2DimStringArray`: [`[["key1", "val1"], ["key2", "val2"], ["key3", "val3"] ]`],
		`json2DimIntArray`: [`[ [123, 456], [789, 1011], [543, 321] ]`]
	];
	IFormData formData1 = new FormData(rawData1);
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
		int[] jsonIntArray;
		string[] jsonStringArray;
		int[][] json2DimIntArray;
		string[][] json2DimStringArray;
	}

	static struct StructData2
	{
		Optional!bool boolParam;
		Optional!int intParam;
		Optional!double floatParam;
		Optional!string stringParam;
		Optional!Date partDateParam;
		Optional!Date wholeDateParam;
		Optional!Date emptyDateParam;
		OptionalDate optEmptyDateParam;
		Optional!(int[]) emptyIntArrayParam;
		Optional!(int[]) nullIntArrayParam;
		Optional!InternalStruct1 structParam;
		OptionalDate optDateParam1;
		OptionalDate optDateParam2;
		OptionalDate optDateParam3;
		OptionalDate optDateParam4;
		Optional!(int[]) jsonIntArray;
		Optional!(string[]) jsonStringArray;
		Optional!(int[][]) json2DimIntArray;
		Optional!(string[][]) json2DimStringArray;
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
	assert(equal(strucData1.jsonIntArray, [1, 2, 3]));
	assert(equal(strucData1.jsonStringArray, ["may", "jun", "jul"]));
	assert(equal(strucData1.json2DimIntArray, [[123, 456], [789, 1011], [543, 321]]));
	assert(equal(strucData1.json2DimStringArray, [["key1", "val1"], ["key2", "val2"], ["key3", "val3"]]));

	StructData2 structData2;
	formDataToStruct(formData1, structData2);
	assert(structData2.boolParam == true);
	assert(structData2.intParam == 10);
	assert(structData2.floatParam == 13.13);
	assert(structData2.stringParam == `testParam`);
	assert(structData2.partDateParam.toISOExtString() == `2017-08-15`);
	assert(structData2.wholeDateParam.toISOExtString() == `2017-08-16`);
	assert(structData2.emptyDateParam.isNull);
	assert(structData2.optEmptyDateParam.isNull);
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
	assert(equal(structData2.jsonIntArray.value, [1, 2, 3]));
	assert(equal(structData2.jsonStringArray.value, ["may", "jun", "jul"]));
	assert(equal(structData2.json2DimIntArray.value, [[123, 456], [789, 1011], [543, 321]]));
	assert(equal(structData2.json2DimStringArray.value, [["key1", "val1"], ["key2", "val2"], ["key3", "val3"]]));

	struct StructData3
	{
		Undefable!bool boolParam;
		Undefable!int intParam;
		Undefable!double floatParam;
		Undefable!string stringParam;
		Undefable!bool emptyBoolParam;
		Undefable!int emptyIntParam;
		Undefable!float emptyFloatParam;
		Undefable!string emptyStringParam;
		Undefable!Date partDateParam;
		Undefable!Date wholeDateParam;
		Undefable!Date emptyDateParam;
		Undefable!(int[]) emptyIntArrayParam;
		Undefable!(int[]) nullIntArrayParam;
		Undefable!InternalStruct1 structParam;
		Undefable!int nonExistentInt;
		Undefable!string nonExistentString;
		Undefable!Date nonExistentDate;
	}

	StructData3 structData3;
	formDataToStruct(formData1, structData3);
	assert(structData3.boolParam == true);
	assert(structData3.intParam == 10);
	assert(structData3.floatParam == 13.13);
	assert(structData3.stringParam == `testParam`);
	assert(structData3.emptyBoolParam.isNull);
	assert(!structData3.emptyBoolParam.isUndef);
	assert(structData3.emptyIntParam.isNull);
	assert(!structData3.emptyIntParam.isUndef);
	assert(structData3.emptyFloatParam.isNull);
	assert(!structData3.emptyFloatParam.isUndef);
	assert(!structData3.emptyStringParam.isNull); // Not treated as null when empty string
	assert(!structData3.emptyStringParam.isUndef); // Not treated as null when empty string
	assert(structData3.partDateParam.toISOExtString() == `2017-08-15`);
	assert(structData3.wholeDateParam.toISOExtString() == `2017-08-16`);
	assert(structData3.emptyDateParam.isNull);
	assert(!structData3.emptyDateParam.isUndef);
	assert(structData3.emptyIntArrayParam.isNull);
	assert(!structData3.emptyIntArrayParam.isSet);
	assert(structData3.nullIntArrayParam.isNull);
	assert(!structData3.nullIntArrayParam.isSet);
	assert(structData3.structParam.intSub == -30);
	assert(structData3.structParam.floatSub == -30.3);
	assert(structData3.structParam.stringSub == `trololo`);
	assert(structData3.nonExistentInt.isUndef);
	assert(structData3.nonExistentString.isUndef);
	assert(structData3.nonExistentDate.isUndef);
}