module webtank.ui.control;

///Элемент пользовательского интерфейса
interface UIControl
{
	///Название элемента интерфейса
	string controlName() const @property;
	void controlName(string name) @property;

	///Название типа элемента интерфейса (свойство для чтения)
	string controlTypeName() const @property;
}

///Элемент пользовательского интерфейса на базе HTML
interface HTMLControl: UIControl
{
	///Задает базовое имя поля данных, задаваемого элементом интерфейса.
	///Обычно задает значения HTML-аттрибутов name. Названия полей данных
	///могут строиться на базе этого значения с добавлением каких-либо префиксов
	///или суффиксов
	void dataFieldName( string value ) @property;
	string dataFieldName() const @property;
	
	///Добавление классов для элементов внутри компонента
	void addElementHTMLClasses( string element, string classes );

	///Путь для поиска шаблонов компонента
	//void templatesPath( string path ) @property;
	
	///Выполняет создание верстки для элемента интерфейса
	string print();
}

///HTML-элемент пользовательского интерфейса с применением методологии
///верстки "Экземпляр-Тема-Элемент-Модификатор" (ITEM)
interface ITEMControl: HTMLControl
{
	///Возвращает HTML класс "экземпляра" блока по методологии ITEM
	///для данного элемента интерфейса
	string instanceHTMLClass() const @property;

	///Добавляет дополнительные классы тем оформления блока
	void addThemeHTMLClasses( string themes );

}

mixin template ITEMControlBaseImpl()
{
	public override {
		string controlName() const @property
		{
			return _controlName;
		}

		void controlName(string name) @property
		{
			_controlName = name;
		}

		string instanceHTMLClass() const @property
		{
			return wtInstanceHTMLClassPrefix ~ _controlName;
		}

		void dataFieldName(string value) @property
		{
			_dataFieldName = value;
		}

		string dataFieldName() const @property
		{
			return _dataFieldName;
		}

		void addThemeHTMLClasses( string themes )
		{
			import std.string: split;
			_themeHTMLClasses ~= themes.split(' ');
		}
	}

protected:
	string _controlName;
	string[] _themeHTMLClasses;
	string _dataFieldName;
}

mixin template AddElementHTMLClassesImpl()
{
	public override void addElementHTMLClasses( string element, string classes )
	{
		import std.array: split;
		import std.algorithm: canFind;
		import webtank.common.utils: getPtrOrSet;

		if( !this._allowedElemsForClasses.canFind(element) ) //Unregistered elements are ignored
			return;

		auto classesPtr = _elementHTMLClasses.getPtrOrSet(element);
		*classesPtr ~= classes.split(' ');
	}

	protected string[] _getHTMLClasses( string element )
	{
		return
			[ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ element ]
			~ _elementHTMLClasses.get( element, null )
			~ this._themeHTMLClasses;
	}

	protected string _printHTMLClasses( string element )
	{
		import std.string: join;
		return this._getHTMLClasses(element).join(' ');
	}

protected:
	string[][string] _elementHTMLClasses;
}

//Block, Element, Modifier (BEM) concept prefixes for element classes
///Prefix for Webtank instance class, used for manipulating block elements via JavaScript
static immutable wtInstanceHTMLClassPrefix = `i-`;
///Prefix for Webtank theme class, used to set styling for block elements with CSS
static immutable wtThemeHTMLClassPrefix = `t-wt-`;
///Prefix for Webtank element class, used for addressing ceratain elements in JavaScript or CSS
static immutable wtElementHTMLClassPrefix = `e-`;
///Prefix for Webtank modifier class, used to modify elements or whole block via CSS
static immutable wtModifierHTMLClassPrefix = `m-wt-`;
