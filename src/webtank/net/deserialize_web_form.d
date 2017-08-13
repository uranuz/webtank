module webtank.net.deserialize_web_form;

import std.traits: isBoolean, isIntegral, isFloatingPoint, isSomeString, isArray;
import std.conv: to;
import std.meta: Alias;
import std.typecons;
import std.datetime: Date, DateTime, SysTime, TimeOfDay;
import std.range: ElementType;

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
		return value.to!T;
	} else static if( is( T == Date ) || is( T == DateTime ) || is( T == SysTime ) || is( T == TimeOfDay ) ) {
		return T.fromISOExtString(value);
	} else {
		static assert(false, T.stringof ~ ` is not plain type!!!`);
	}
}

/** Автоматический перевод web-формы в структуру Struc */
void formDataToStruct(Struc, string subFieldDelim = "__", string arrayElemDelim = ",")(
	FormData formData, ref Struc result, string prefix = null)
	if( is( Struc == struct ) )
{
	import std.algorithm: splitter;
	foreach( structFieldName; __traits(allMembers, Struc) )
	{
		static if(__traits(compiles, {
			__traits(getMember, result, structFieldName) = typeof(__traits(getMember, result, structFieldName)).init;
		})) {
			alias BaseFieldType = typeof(__traits(getMember, result, structFieldName));
			alias Field = Alias!(__traits(getMember, result, structFieldName));
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
					if( !isOptional!BaseFieldType || isSomeString!BaseFieldType || (*formFieldPtr).length > 0 && (*formFieldPtr) != "null" )
					{
						static if( isPlainType!FieldType )
						{
							__traits(getMember, result, structFieldName) = convertPlainType!FieldType(*formFieldPtr).to!FieldType;
						}
						else static if( isArray!FieldType )
						{
							alias Elem = ElementType!FieldType;
							static assert(isPlainType!Elem, Elem.stringof ~ ` is not allowed array element type!!!`);
							if( formData.array(fieldName).length == 1 ) {
								Elem[] innerArray = __traits(getMember, result, structFieldName);
								foreach( item; splitter(*formFieldPtr, arrayElemDelim) ) {
									innerArray ~= convertPlainType!Elem(item);
								}
								__traits(getMember, result, structFieldName) = innerArray;
							} else {
								__traits(getMember, result, structFieldName) = formData.array(fieldName).to!(Elem[]);
							}
						}
					}
					else
					{
						static if( isOptional!BaseFieldType ) {
							__traits(getMember, result, structFieldName) = null;
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
				__traits(getMember, result, structFieldName) = innerStruct;
			}
		}
	}
}