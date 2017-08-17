module webtank.net.deserialize_web_form;

import std.traits: isBoolean, isIntegral, isFloatingPoint, isSomeString, isArray;
import std.meta: Alias;
import std.typecons;
import std.datetime: Date, DateTime, SysTime, TimeOfDay;
import std.range: ElementType;

import webtank.common.conv: conv;
import webtank.common.optional;
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
		|| is( T == TimeOfDay );
}

template isPrimaryType(T) {
	enum bool isPrimaryType = isPlainType!T || isArray!T;
}

auto convertPlainType(T)(string value)
{
	import std.algorithm: canFind;
	static if( isBoolean!T ) {
		return ["on", "true", "yes", "да"].canFind(value);
	}
	else static if( isIntegral!T || isFloatingPoint!T || isSomeString!T ) {
		return value.conv!T;
	} else static if( is( T == Date ) || is( T == DateTime ) || is( T == SysTime ) || is( T == TimeOfDay ) ) {
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
void formDataToStruct(StrucBase, string subFieldDelim = "__", string arrayElemDelim = ",")(
	FormData formData, ref StrucBase result, string prefix = null)
	if( is( StrucBase == struct ) )
{
	static if( isOptional!StrucBase ) {
		alias Struc = OptionalValueType!StrucBase;
	} else {
		alias Struc = StrucBase;
	}
	import std.algorithm: splitter;
	foreach( structFieldName; __traits(allMembers, Struc) )
	{
		static if(__traits(compiles, {
			__traits(getMember, result, structFieldName) = typeof(__traits(getMember, result, structFieldName)).init;
		})) {
			alias BaseFieldType = typeof(__traits(getMember, Struc, structFieldName));
			static if( isOptional!BaseFieldType ) {
				alias FieldType = OptionalValueType!BaseFieldType;
			} else {
				alias FieldType = BaseFieldType;
			}
			string fieldName = (prefix.length? prefix ~ subFieldDelim: null) ~ structFieldName;
			static if( isPrimaryType!FieldType )
			{
				if( auto formFieldPtr = fieldName in formData )
				{
					if( !isOptional!BaseFieldType || isSomeString!FieldType || (*formFieldPtr).length > 0 && (*formFieldPtr) != "null" )
					{
						static if( isPlainType!FieldType )
						{
							setOfMaybeNull!structFieldName(result, convertPlainType!FieldType(*formFieldPtr));
						}
						else static if( isArray!FieldType )
						{
							alias Elem = ElementType!FieldType;
							static if( isPlainType!Elem ) {
								if( formData.array(fieldName).length == 1 ) {
									Elem[] innerArray = __traits(getMember, result, structFieldName);
									foreach( item; splitter(*formFieldPtr, arrayElemDelim) ) {
										innerArray ~= convertPlainType!Elem(item);
									}
									setOfMaybeNull!structFieldName(result, innerArray);
								} else {
									setOfMaybeNull!structFieldName(result, formData.array(fieldName).conv!(Elem[]));
								}
							}
						}
					}
					else
					{
						static if( isOptional!BaseFieldType ) {
							setOfMaybeNull!structFieldName(result, null);
						}
					}
				}
			}
			// Здесь нет else, чтобы можно было задать, например, дату как совокупность подполей так и целиком в виде строки формата ISO
			static if( is( FieldType == struct ) )
			{
				// Здесь может быть функция-свойство, а не простое поле, поэтому читаем значение, затем меняем
				// и снова записываем, чтобы изменить в структуре только те поля, которые надо
				BaseFieldType innerStruct = __traits(getMember, result, structFieldName);
				formDataToStruct(formData, innerStruct, fieldName);
				setOfMaybeNull!structFieldName(result, innerStruct);
			}
		}
	}
}

unittest
{
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
		`structParam__wholeDateSub`: [`2019-10-23`]
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
	}

	static struct StructData2
	{
		Optional!bool boolParam;
		Optional!int intParam;
		Optional!double floatParam;
		Optional!string stringParam;
		Optional!Date partDateParam;
		Optional!Date wholeDateParam;
		Optional!InternalStruct1 structParam;
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

	StructData2 structData2;
	formDataToStruct(formData1, structData2);
	assert(structData2.boolParam == true);
	assert(structData2.intParam == 10);
	assert(structData2.floatParam == 13.13);
	assert(structData2.stringParam == `testParam`);
	assert(structData2.partDateParam.toISOExtString() == `2017-08-15`);
	assert(structData2.wholeDateParam.toISOExtString() == `2017-08-16`);
	assert(structData2.structParam.intSub == -30);
	assert(structData2.structParam.floatSub == -30.3);
	assert(structData2.structParam.stringSub == `trololo`);
}