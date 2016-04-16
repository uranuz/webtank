module webtank.ui.control;

///Элемент пользовательского интерфейса
interface UIControl
{
	///Название элемента интерфейса
	string controlName() @property;
}

///Элемент пользовательского интерфейса на базе HTML
interface HTMLControl: UIControl
{
	///Задает базовое имя поля данных, задаваемого элементом интерфейса.
	///Обычно задает значения HTML-аттрибутов name. Названия полей данных
	///могут строиться на базе этого значения с добавлением каких-либо префиксов
	///или суффиксов
	void dataFieldName( string value ) @property;
	
	///Добавление классов для элементов внутри компонента
	void addElementClasses( string element, string classes );
	
	///Выполняет создание верстки для элемента интерфейса
	string print();
}

///HTML-элемент пользовательского интерфейса 
///с применением методологии "Блок-Элемент-Модификатор" (БЭМ)
interface BEMControl: HTMLControl
{
	///Возвращает имя блока по методологии БЭМ для данного элемента интерфейса
	string blockName() @property;
}

mixin template AddClassesImpl()
{
	override void addElementClasses( string element, string classes )
	{
		import std.array: split;
		import std.algorithm: canFind;
		import webtank.common.utils: getPtrOrSet;
		
		if( !this._allowedElemsForClasses.canFind(element) ) //Unregistered elements are ignored
			return;
		
		auto classesPtr = _elementClasses.getPtrOrSet(element);
		*classesPtr ~= classes.split(' ');
	}
	
	protected {
		string[][string] _elementClasses;
	}

}

//Block, Element, Modifier (BEM) concept prefixes for element classes
static immutable blockPrefix = `b-wt-`;
static immutable elementPrefix = `e-wt-`;
static immutable modifierPrefix = `m-wt-`;
