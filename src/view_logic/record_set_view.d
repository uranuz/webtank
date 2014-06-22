module webtank.view_logic.record_set_view;

import std.conv;

import webtank.datctrl.record_set;

enum FieldViewManner 
{	plainText, simpleControls }

struct FieldViewFormat
{	string cellHTMLClass;
	string headerHTMLClass;
	FieldViewManner viewManner;
	bool isEditable = false; //По-умолчанию не редактируемый
	bool isVisible = true;
	string nullStr;
	string trueStr;
	string falseStr;
	//string titleNullStr;
}

class FieldView
{	
public:
	IDataField field;
	IDataField titleField;

	FieldViewFormat format;
	this(IDataField field, IDataField titleField)
	{	_field = field; _titleField = titleField; }
	
	this(IDataField field)
	{	_field = field; }
	
	string _printHeaderCell()
	{	return `<th>` ~ _field.name ~ `</th>`;
	}
	
	string _printCell(ICell curCell)
	{	auto curViewManner = format.viewManner;
		bool curIsEditable = format.isEditable;
		string curNullStr = format.nullStr;
		string curTrueStr = format.trueStr;
		string curNullStr = format.falseStr;
		string resultStr = `<td`
			~ ( ( FieldHTMLClasses[j].length > 0 ) ? (` class="` ~ FieldHTMLClasses[j] ~ `"`) : "" ) ~ `>`;
		with( FieldViewManner ) {
		switch( curViewManner )
		{	case plainText:
			{	if( curCell.isNull() )
					resultStr ~= curNullStr;
				else
					resultStr ~= curCell.getStr();
				break;
			}
			case simpleControls: 
			{	string nameAttribStr = ` name="` ~ recordSet.getField(j).name ~ `_` ~ recordSet._frontKey.to!string ~ `"`;
				if( curCell.type == FieldType.Int || curCell.type == FieldType.Str || curCell.type == FieldType.IntKey )
				{	resultStr ~= `<input type="text"` ~ nameAttribStr ~ ` value="`
						~ ( ( curCell.isNull() ) ? curNullStr : curCell.getStr() ) ~`"` 
						~ ( ( !curIsEditable ) ? ` disabled` : `` ) ~ `>`;
				}
				if( curCell.type == FieldType.Bool )
				{	string nullSelStr = ( curCell.isNull() ) ? ` selected` : ``;
					string yesSelStr = ``;
					string noSelStr = ``;
					if( !curCell.isNull() )
					{	if( curCell.getBool() ) yesSelStr = ` selected`;
						else noSelStr = ` selected`;
					}
					resultStr ~= `<select` ~ nameAttribStr ~ ( ( !curIsEditable ) ? ` disabled` : `` ) ~ `>`;
					if( curCell.isNullable )
						resultStr ~= `<option value="null"` ~ nullSelStr ~ `>` ~ curNullStr ~ `</option>`;
						
					resultStr ~= 
					`<option value="yes"` ~ yesSelStr ~ `>` ~ curTrueStr ~`</option>`
					`<option value="no"` ~ noSelStr ~ `>` ~ curFalseStr ~`</option>`
					`</select>`;
				}
				break;
			}
			default:
			
			break;
		}  
		}  //with( FieldViewManner )
		resultStr ~= `</td>`;
		return resultStr;
	}
}

struct Pair(F, S)
{	F first;
	S second;
	ref F f() @property
	{	return first; }
	ref S s() @property
	{	return second; }
}

class RecordSetView
{	
protected:
	FieldView[] _fieldViews;
	RecordSet _recordSet;
	size_t[string] _byFieldIndexes;
	size_t[size_t] _byFieldNames;
	
public:
	bool showHeader = true;
	string HTMLTableClass;
	//string nullStrDefault = `Не задано`;
	//string trueStrDefault = `Да`;
	//string falseStrDefault = `Нет`;
public:
	this( RecordSet recSet )
	{	_recordSet = recSet; }
	
	this( RecordSet recSet, string[] outputFieldNames )
	{	_recordSet = recSet;
		//Получить поле с заданным именем и передать его в FieldView
		foreach( name; outputFieldNames)
		{	auto foundField = _recordSet.getField(name);
			if( foundField !is null )
				_fieldViews ~= new FieldView(foundField);
		}
	}
	
	this( RecordSet recSet, size_t[] outputFieldIndexes )
	{	_recordSet = recSet;
		//Получить поле с заданным индексом и передать его в FieldView
		foreach( index; outputFieldIndexes)
		{	auto foundField = _recordSet.getField(index);
			if( foundField !is null )
				_fieldViews ~= new FieldView(foundField);
		}
	}
	
	/*this( RecordSet recSet, Pair!(size_t, FieldViewFormat)[])
	{
		
	}
	
	this( RecordSet recSet, string[] outputFieldNames, FieldViewFormat[string] outputFieldFormats )
	{	_recordSet = recSet;
		//Получить поле с заданным именем и передать его в FieldView
		foreach( name; outputFieldNames)
		{	auto foundField = _recordSet.getField(name);
			if( foundField !is null )
			{	_fieldViews ~= new FieldView(foundField);
				import std.array;
				_fieldViews
			}
			
		}
	}*/
	
	//this( RecordSet recSet, FieldViewFormat[size_t] outputFieldFormats )
	//{	
		
	//}
	
	//Получение ссылки на формат
	ref FieldViewFormat getFormatRefAt(size_t position)
	{	return _fieldViews[position].format; }
	
	void setFormats(Field)
	
	void setTitleField(IDataField field, size_t position)
	{	return _fieldViews[position].titleField = field;
	}
	
	
	
	string getHTMLStr()
	{	string resultStr = `<table` ~ ( ( HTMLTableClass.length > 0 ) ? (` class="` ~ HTMLTableClass ~ `"`) : `` ) ~ `>`;
		resultStr ~= `<tr>`;
		if( showHeader )
		{	for( int k = 0; k < recordSet.fieldCount; ++k )
			{	resultStr ~= _fieldViews[k]._printHeaderCell(); }
		}
		resultStr ~= `</tr>`;
		
		//TODO: Добавить окошечки для фильтрации, если надо
		foreach( rec; recordSet )
		{	resultStr ~= `<tr>`;
			for( size_t j = 0; j < recordSet.fieldCount; ++j )
			{	resultStr ~= _fieldViews[j]._printCell( rec[j] );
			}
			resultStr ~= `</tr>`;
		}
		resultStr ~= `</table>`;
		return resultStr;
	}
}