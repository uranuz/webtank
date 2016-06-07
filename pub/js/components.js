//Определяем пространство имён библиотеки
var webtank = {
	version: "0.0",
	inherit: function (proto) {
		function F() {}
		F.prototype = proto;
		var object = new F;
		return object;
	},
	//Глубокая копия объекта
   deepCopy: function(o) {
		var i, c, p, v;
		if( !o || "object" !== typeof o ) 
		{	return o;
		}
		else if( o instanceof Array )
		{	c = [];
			for( i = 0; i < o.length; i++)
				c.push( webtank.deepCopy(o[i]) );
		}
		else 
		{	c = {};
			for(p in o) {
				if( o.hasOwnProperty(p) ) {
					c[p] = webtank.deepCopy(o[p]);
				}
			}
		}
		return c;
   },
	//Поверхностная копия объекта (если свойства объекта
	//являются объектами, то копируются лишь ссылки)
	copy: function(o) {
		return jQuery.extend({}, o);
	},
	isInteger: function(num) {
		return Math.max(0, num) === num;
	},
	isUnsigned: function(num) {
		return Math.round(num) === num;
	},
	getXMLHTTP: function() {
		var xmlhttp;
		try {
			xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
			try {
				xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
			} catch (E) {
				xmlhttp = false;
			}
		}
		if (!xmlhttp && typeof XMLHttpRequest!='undefined') {
			xmlhttp = new XMLHttpRequest();
		}
		return xmlhttp;
	},
	parseGetParams: function() { 
		var $_GET = {}; 
		var __GET = window.location.search.substring(1).split("&"); 
		for(var i=0; i<__GET.length; i++) { 
			var getVar = __GET[i].split("="); 
			$_GET[getVar[0]] = typeof(getVar[1])=="undefined" ? "" : getVar[1]; 
		} 
		return $_GET; 
	},
	getScrollTop: function() {
		return (  
			(window.pageYOffset !== undefined) ? window.pageYOffset : 
			(document.documentElement || document.body.parentNode || document.body).scrollTop
		);
	},
	getScrollLeft: function() {
		return (
			(window.pageXOffset !== undefined) ? window.pageXOffset : 
			(document.documentElement || document.body.parentNode || document.body).scrollLeft
		);
	}
};

if (!Function.prototype.bind) {
  Function.prototype.bind = function(oThis) {
    if (typeof this !== 'function') {
      // ближайший аналог внутренней функции
      // IsCallable в ECMAScript 5
      throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable');
    }

    var aArgs = Array.prototype.slice.call(arguments, 1),
        fToBind = this,
        fNOP    = function() {},
        fBound  = function() {
          return fToBind.apply(this instanceof fNOP && oThis
                 ? this
                 : oThis,
                 aArgs.concat(Array.prototype.slice.call(arguments)));
        };

    fNOP.prototype = this.prototype;
    fBound.prototype = new fNOP();

    return fBound;
  };
}

var __hasProp = {}.hasOwnProperty;
function __extends(child, parent) {
	for (var key in parent) {
		if (__hasProp.call(parent, key)) 
			child[key] = parent[key];
	}
	
	function ctor() { 
		this.constructor = child; 
	}
	
	ctor.prototype = parent.prototype;
	
	child.prototype = new ctor();
	child.__super__ = parent.prototype;
	
	return child; 
}

function __mixinProto(dst, src) {
	for( key in src ) {
		//Don't copy Object's built in properties
		if( (typeof {}[key] == "undefined") || ({}[key] != src[key]) )
			dst.prototype[key] = src[key];
	}
	
	return dst;
}


webtank.ITEMControl = new (function(_super) {
	function ITEMControl(opts) {
		opts = opts || {}
		this._controlName = opts.controlName;
		this._controlTypeName = opts.controlTypeName;
		this._elemsCache = null;
		this._cssBlockName = opts.cssBlockName;
	}
	
	return __mixinProto(ITEMControl, {

		//Возвращает имя экземпляра компонента интерфейса
		controlName: function() {
			return this._controlName;
		},

		//Возвращает имя типа компонента интерфейса
		controlTypeName: function() {
			return this._controlTypeName;
		},

		//Возвращает HTML-класс экземпляра компонента интерфейса
		instanceHTMLClass: function() {
			return this._controlName ? 'i-' + this._controlName : undefined;
		},

		//Возвращает jQuery-список HTML-элементов с классами экземпляра
		//компонента интерфейса.
		//Это protected-метод для использования только в производных классах
		_elems: function( update ) {
			if( this._elemsCache == null || update === true ) {
				this._elemsCache = $( '.' + this.instanceHTMLClass() );
			}
			return this._elemsCache;
		},

		$el: function(elemSelector) {
			var 
				self = this,
				elems;
			
			if( elemSelector.indexOf(".b-") !== -1 )
				throw new Error("Block selectors are not allowed!!!");
			
			elems = this.elems.filter(elemSelector);
			elems.$on = function(types, selector, data, fn, /*INTERNAL*/ one) {
				var args = [types];
				
				// Types can be a map of types/handlers
				if ( typeof types === "object" ) {
					// ( types-Object, selector, data )
					if ( typeof selector !== "string" ) {
						// ( types-Object, data )
						data = data || selector;
						selector = undefined;
					}
					for ( type in types ) {
						this.$on( type, selector, data, types[ type ], one );
					}
					return this;
				}

				if ( data == null && fn == null ) {
					// ( types, fn )
					fn = selector;
					data = selector = undefined;
				} else if ( fn == null ) {
					if ( typeof selector === "string" ) {
						// ( types, selector, fn )
						fn = data;
						data = undefined;
					} else {
						// ( types, data, fn )
						fn = data;
						data = selector;
						selector = undefined;
					}
				}
				
				if( selector != null )
					args.push( self.__parseSelector(selector) );
				if( data != null )
					args.push( data );
				
				args.push(function(ev) {
					fn.call(self, ev, $(this));
				});

				this.on.apply(this, args);
			};
			
			return elems;
		},
		$on: function() {
			return $(this).on.apply($(this), arguments);
		},
		$off: function() {
			return $(this).off.apply($(this), arguments);
		},
		$trigger: function() {
			return $(this).trigger.apply($(this), arguments);
		},
		$triggerHandler: function() {
			return $(this).triggerHandler.apply($(this), arguments);
		},
		__parseSelector: function(selector)
		{
			var newSelector = selector;
			if( selector.indexOf(".b-") !== -1 )
				throw new Error("Block selectors are not allowed!!!");
			
			blockName = ( this._cssBlockName == null || this._cssBlockName.length == 0 ) ? this.elems.selector : this._cssBlockName;

			newSelector = selector.split(".e-").join(blockName + ".e-");
			
			return newSelector;
		}
	});
})();

//Определяем пространство имен для JSON-RPC
webtank.json_rpc = 
{	defaultInvokeArgs:  //Аргументы по-умолчанию для вызова ф-ции invoke
	{	uri: "/",  //Адрес для отправки
		method: null, //Название удалённого метода для вызова в виде строки
		params: null, //Параметры вызова удалённого метода
		success: null, //Обработчик успешного вызова удалённого метода
		error: null,  //Обработчик ошибки
		complete: null, //Обработчик завершения (после success или error)
		id: null //Идентификатор соединения
	},
	_counter: 0,
	_responseQueue: [null],
	_generateId: function(args)
	{	return webtank.json_rpc._counter++;
	},
	invoke: function(args) //Функция вызова удалённой процедуры
	{	var 
			undefined = ( function(undef){ return undef; })(),
			_defArgs = webtank.json_rpc.defaultInvokeArgs,
			_args = _defArgs;
		
		if( args )
			_args = args;
		
		_args.params = webtank.json_rpc._processParams(_args.params);

		var xhr = webtank.getXMLHTTP();
		xhr.open( "POST", _args.uri, true );
		xhr.setRequestHeader("content-type", "application/json-rpc");
		//
		xhr.onreadystatechange = function() {	webtank.json_rpc._handleResponse(xhr); }
		var idStr = "";
		if( _args.error || _args.success || _args.complete )
		{	if( !_args.id )
				_args.id = webtank.json_rpc._generateId(_args);
			webtank.json_rpc._responseQueue[_args.id] = _args;
			idStr = ',"id":"' + _args.id + '"';
		}
		xhr.send( '{"jsonrpc":"2.0","method":"' + _args.method + '","params":' + _args.params + idStr + '}' );
	},
	_handleResponse: function(xhr) 
	{	if( xhr.readyState === 4 ) 
		{	var 
				responseJSON = JSON.parse(xhr.responseText),
				invokeArgs = null;
			
			if( responseJSON.id )
			{	invokeArgs = webtank.json_rpc._responseQueue[responseJSON.id];
				if( invokeArgs )
				{	delete webtank.json_rpc._responseQueue[responseJSON.id];
					if( responseJSON.error )
					{	if( invokeArgs.error )
							invokeArgs.error(responseJSON);
						else
						{	console.error("Ошибка при выполнении удалённого метода");
							console.error(responseJSON.error.toString());
						}
					}
					else
					{	if( invokeArgs.success )
							invokeArgs.success(responseJSON.result);
					}
					if( invokeArgs.complete )
						invokeArgs.complete(responseJSON);
				}
			}
		}
	},
	_processParams: function(params) {
		if( typeof params === "object" )
			return JSON.stringify(params);
		else if( (typeof params === "function") || (typeof params === "undefined") )
			return '"null"';
		else if( typeof params === "string" )
			return '"' + params + '"';
		else //Для boolean, number
			return params; 
	}
};

webtank.datctrl = {
	//трансформирует JSON в Record или RecordSet
	fromJSON: function(json) {
		var 
			dctl = webtank.datctrl,
			jsonObj = json, fmt;
		
		if( jsonObj.t === "record" || jsonObj.t === "recordset" )
		{	
			fmt = dctl.recordFormatFromJSON(jsonObj);
				
			if( jsonObj.t === "record" )
			{	return new dctl.Record({
					format: fmt,
					data: jsonObj.d
				});
			}
			else if( jsonObj.t === "recordset" )
			{	return new dctl.RecordSet({
					format: fmt,
					data: jsonObj.d
				});
			}
		}
	},
	recordFormatFromJSON: function(jsonObj) {
		var 
			dctl = webtank.datctrl, 
			kfi = jsonObj.kfi || 0,
			jFormats = jsonObj.f, 
			enumFormats = {},
			i = 0, jFmt;
			
		for( ; i < jFormats.length; ++i )
		{
			jFmt = jFormats[i];
			if( jFmt.enum )
			{
				enumFormats[i] = new dctl.EnumFormat({
					items: jFmt.enum
				});
			}
		}
		
		return new dctl.RecordFormat({
			fields: jFormats,
			enumFormats: enumFormats,
			keyFieldIndex: kfi
		});
	}
};

webtank.datctrl.Record = (function() {
	var dctl = webtank.datctrl;
	
	function Record(opts) {
		opts = opts || {};
		if( opts.format != null && opts.fields != null ) {
			console.error('Format or fields option should be provided but not both!!! Still format is priorite option..');
		}
		
		if( opts.format instanceof dctl.RecordFormat ) {
			this._fmt = opts.format; //Формат записи (RecordFormat)
		} else {
			this._fmt = new dctl.RecordFormat({fields: opts.fields});
		}
		
		if( opts.data instanceof Array )
			this._d = opts.data;
		else
			this._d = []; //Данные (массив)
	}
	
	return __mixinProto(Record, {
		//Метод получения значения из записи по имени поля
		get: function(index, defaultValue) {
			var val;
			if( webtank.isUnsigned(index) )
			{	//Вдруг там массив - лучше выдать копию
				val = webtank.deepCopy( this._d[ index ] );
			}
			else
			{	//Вдруг там массив - лучше выдать копию
				val = webtank.deepCopy( this._d[ this._fmt.getIndex(index) ] );
			}
			if( val == null )
				return defaultValue;
			else
				return val;
		},
		getLength: function() {
			return this._d.length;
		},
		copyFormat: function() {
			return this._fmt.copy();
		},
		getKey: function() {
			return this._d[ this._fmt._keyFieldIndex ];
		},
		getKeyFieldIndex: function() {
			return this._fmt._keyFieldIndex;
		},
		set: function() {
			//Не используй меня. Я пустой!..
			//...или реализуй меня и используй
		},
		getIsEmpty: function() {
			return !this._d.length && this._fmt.getIsEmpty();
		},
		copy: function() {
			return new Record({
				format: this._fmt.copy(),
				data: webtank.deepCopy( this._d )
			});
		}
	});
})();

webtank.datctrl.RecordSet = (function() {
	var
		dctl = webtank.datctrl;
		
	function RecordSet(opts) {
		opts = opts || {}
		if( opts.format != null && opts.fields != null ) {
			console.error('Format or fields option should be provided but not both!!! Still format is priorite option..');
		}
		
		if( opts.format instanceof dctl.RecordFormat ) {
			this._fmt = opts.format; //Формат записи (RecordFormat)
		} else {
			this._fmt = new dctl.RecordFormat({fields: opts.fields});
		}
		
		if( opts.data instanceof Array )
			this._d = opts.data;
		else
			this._d = []; //Данные (массив)
		
		this._recIndex = 0;
		this._reindex(); //Строим индекс
	}
	
	return __mixinProto(RecordSet, {
		//Возращает след. запись или null, если их больше нет
		next: function() {
			var rec = this.getRecordAt(this._recIndex);
			this._recIndex++;
			return rec;
		},
		//Возвращает true, если есть ещё записи, иначе - false
		hasNext: function() {
			return (this._recIndex < this._d.length);
		},
		//Сброс итератора на начало
		rewind: function() {
			this._recIndex = 0;
		},
		copyFormat: function()
		{	return this._fmt.copy();
		},
		//Возвращает количество записей в наборе
		getLength: function() {
			return this._d.length;
		},
		//Возвращает запись по ключу
		getRecord: function(key) {
			if( this._indexes[key] == null )
				return null;
			else
				return this.getRecordAt( this._indexes[key] );
		},
		//Возвращает запись по порядковому номеру index
		getRecordAt: function(index) {
			if( index < this._d.length )
				return new dctl.Record({
					format: this._fmt,
					data: this._d[index]
				});
			else
				return null;
		},
		//Возвращает значение первичного ключа по порядковому номеру index
		getKey: function(index) {
			return this._d[ this._fmt.getKeyFieldIndex() ][index];
		},
		//Возвращает true, если в наборе имеется запись с ключом key, иначе - false
		hasKey: function(key) {
			if( this._indexes[key] == null )
				return false;
			else
				return true;
		},
		//Возвращает порядковый номер поля первичного ключа в наборе записей
		getKeyFieldIndex: function() {
			return this._fmt.getKeyFieldIndex();
		},
		//Добавление записи rec в набор записей
		append: function(rec) {
			if( this.getIsEmpty || this._fmt.equals(rec._fmt) )
			{	
				if( this._fmt.getIsEmpty() )
					this._fmt = rec._fmt.copy();
				this._indexes[ rec.getKey() ] = this._d.length;
				this._d.push(rec._d);
			}
			else
				console.error("Формат записи не совпадает с форматом набора данных!!!");
		},
		remove: function(key) {
			var
				index = this._indexes[key];
			
			if( index !== undefined )
			{	this._d.splice(index, 1);
				this._reindex(index);
			}
			else
				console.error("Запись с ключом " + key + " не содержится в наборе данных!!!");
		},
		_reindex: function(startIndex) {
			var
				i = 0,
				kfi = this.getKeyFieldIndex();
			
			this._indexes = {};
			
			for( ; i < this._d.length ; i++ )
				this._indexes[ this._d[i][ kfi ] ] = i;
		},
		getIsEmpty: function() {
			return !this._d.length && this._fmt.getIsEmpty();
		},
		copy: function() {
			return new dctl.RecordSet({
				format: this._fmt.copy(),
				data: webtank.deepCopy( this._d ),
				keyFieldIndex: this._keyFieldIndex
			});
		}
	});
})();

webtank.datctrl.RecordFormat = (function() {
	var 
		dctl = webtank.datctrl;
	
	function RecordFormat(opts) {
		opts = opts || {}
		if( opts.fields instanceof Array ) {
			this._f = opts.fields;
			this._keyFieldIndex = opts.keyFieldIndex? opts.keyFieldIndex : 0;
		}
		else {
			this._f = [];
			this._keyFieldIndex = 0;
		}
		
		//Expected to be mapping from field index to enum format
		this._enum = opts.enumFormats || {};
		
		this._reindex();
	}
	
	return __mixinProto(RecordFormat, {
		_reindex: function() {
			var key, i;
			this._indexes = {}
			for( i = 0; i < this._f.length; i++ )
			{
				key = this._f[i].n;
				if( key != null )
					this._indexes[key] = i;
			}
		},
		//Функция расширяет текущий формат, добавляя к нему format
		extend: function(format) {
			for( var i = 0; i < format._f.length; i++ )
			{	this._f.push(format._f[i]);
				this._indexes[format.n] = format._f.length;
			}
		},
		//Получить индекс поля по имени
		getIndex: function(name) {
			return this._indexes[name];
		},
		//Получить имя поля по индексу
		getName: function(index) {
			return this._f[ index ].n;
		},
		//Получить тип поля по имени или индексу
		getType: function(index) {
			if( webtank.isUnsigned(index) )
				return this._f[ index ].t;
			else
				return this._f[ this.getFieldIndex(index) ].t;
		},
		getKeyFieldIndex: function() {
			return this._keyFieldIndex;
		},
		equals: function(format) {
			return this._f.length === format._f.length;
		},
		getIsEmpty: function() {
			return !this._f.length;
		},
		copy: function() {
			return new dctl.RecordFormat({
				fields: webtank.deepCopy( this._f ),
				keyFieldIndex: this._keyFieldIndex
			});
		}
	});
})();

webtank.datctrl.EnumFormat = (function() { 
	//TODO: Please, implement me;)
	
	function EnumFormat(opts) {
		this._items = opts.items || [];
		this._names = {};
		this._reindex();
	}
	
	return __mixinProto(EnumFormat, {
		getName: function(value) {
			return this._names[value] || null;
		},
		getValue: function(name) {
			var i = 0, curItem;
			for( ; i < this._items.length; ++i ) {
				curItem = this._items[i];
				if( curItem.n = name )
					return curItem.v;
			}
			return null;
		},
		getStr: function(value) {
			return this.getName(value);
		},
		_reindex: function() {
			var i = 0, curItem;
			for( ; i < this._items.length; ++i ) {
				curItem = this._items[i];
				this._names[ curItem.v ] = curItem.n;
			}
		}
	});
})();


webtank.templating = {};

webtank.templating.plain_templater = {
	Element: (function() {
		function Element(prePos, sufPos, matchOpPos) {
			this.prePos = prePos || 0;
			this.sufPos = sufPos || 0;
			this.matchOpPos = matchOpPos || null;
		}
		
		return __mixinProto(Element, {
			isVar: function() {
				return this.matchOpPos != null;
			}
		});
	})(),
	defaultLexemes: { 
		markPre: "{{", markSuf: "}}", 
		varPre: "{{?", matchOp: ":=", varSuf: "}}"
	},
	//Fills PlainTemplater instance data from Record instance
	fillFromRecord: function(tp, rec) {
		var 
			dctl = webtank.datctrl,
			i = 0, len = rec.getLength(), enumFmt, text = "";
		for( ; i < len; ++i ) {
			text = "";
			enumFmt = rec._fmt._enum[i];
			if( enumFmt instanceof dctl.EnumFormat ) {
				text = enumFmt.getStr( rec.get(i) );
			} else {
				text = rec.get(i);
			}
			tp.set( rec._fmt.getName(i), text );
		}
	}
};


webtank.templating.plain_templater.PlainTemplate = (function() {
	var 
		tplr = webtank.templating.plain_templater;
	
	function PlainTemplate() {
		this._namedEls = {}; //Map of arrays of Element's
		this._indexedEls = []; //Array of Element's'
		this._sourceStr = ""; //Template string
		this._lexValues = tplr.defaultLexemes;
	}
	
	return __mixinProto(PlainTemplate, {
		getString: function(values) {
			var 
				result = "", textStart = 0, markName = "",
				i = 0, len = this._indexedEls.length, el;
			
			for( ; i < len; ++i )
			{
				el = this._indexedEls[i];
				if( el.isVar() )
				{
					throw new Exception("Not implemented yet!"); //TODO; Implement it!
				}
				else
				{
					markName = this._getName(el);
					result += 
						this._sourceStr.substring(textStart, el.prePos)
						+ ( values[markName] || "" );
					textStart = el.sufPos + this._lexValues.markSuf.length;
				}
			}
			result += this._sourceStr.substr(textStart);
			return result;
		},
		init: function(sourceStr, indexedElements) {
			this._sourceStr = sourceStr;
			this._indexedEls = indexedElements;
			this._fillNamedElements();
		},
		hasElement: function(name) {
			return this._namedEls.hasOwnProperty(name);
		},
		_getName: function(elem) {
			return this._sourceStr.substring( 
				elem.prePos + this._lexValues.markPre.length, elem.sufPos  );
		},
		_fillNamedElements: function() {
			var 
				i = 0, len = this._indexedEls.length, curEl, markName;
			
			for( ; i < len; ++i )
			{
				curEl = this._indexedEls[i];
				markName = this._getName(curEl);
				if( this._namedEls[markName] )
					this._namedEls[markName].push(curEl);
				else
					this._namedEls[markName] = [curEl];
			}
		}
	});
})();

webtank.templating.plain_templater.PlainTemplater = (function() {
	var tplr = webtank.templating.plain_templater;
	
	function PlainTemplater(template) {
		this._tpl = template; 
		this._values = {};
	}
	
	return __mixinProto(PlainTemplater, {
		hasElement: function(name) {
			return this._tpl.hasElement(name);
		},
		set: function(markName, value) {
			if( !this._tpl.hasElement(markName) )
				return;
			
			this._values[markName] = value;
		},
		setMult: function(dict) {
			for( name in dict ) {
				if( !dict.hasOwnProperty(name) || !this.hasElement(name) )
					continue;
				
				this._values[name] = dict[name];
			}
		},
		get: function(markName) {
			throw new Error("Not implemented yet!");
		},
		getString: function() {
			return this._tpl.getString(this._values);
		}
	});
})();

webtank.templating.plain_templater.TemplateService = (function() {
	var tplr = webtank.templating.plain_templater;
	
	function TemplateService(uri, method, templates) {
		this._remoteURI = uri || "";
		this._methodName = method || "";
		this._initTemplateNames = templates || [];
		this._templates = {};
	}
	
	return __mixinProto(TemplateService, {
		// templates - имена требуемых шаблонов (массив)
		// callback - ф-ция обработки результата
		getMultAsync: function(names, callback) {
			var 
				self = this,
				namesToLoad = this._chooseToLoad(names);

			if( typeof callback !== 'function' || callback == null )
				throw Error("Callback must be a function!");
			
			if( !namesToLoad.length ) {
				this._tplLoadHandler( {}, names, callback );
			} else {
				webtank.json_rpc.invoke({
					uri: this._remoteURI,
					method: this._methodName,
					params: {templates: namesToLoad},
					success: function(data) { self._tplLoadHandler(data, names, callback); }
				});
			}
		},
		getAsync: function(name, callback) {
			return this.getMultAsync([name], function(data, names) {
				if( callback )
					callback(data[names[0]], names[0]);
			});
		},
		_chooseToLoad: function(names) {
			var 
				namesToLoad = [], i = 0;
			
			if( !(names instanceof Array) )
				throw Error("List of template names must be array of strings");
			
			for( ; i < names.length; ++i )
			{
				if( !this._templates.hasOwnProperty(names[i]) )
					namesToLoad.push(names[i]);
			}
			
			return namesToLoad;
		},
		_tplLoadHandler: function(data, requiredNames, callback) {
			var 
				templates = {}, tpl, jElems, elems = [], i = 0;
			for( name in data )
			{
				if( !data.hasOwnProperty(name) )
					continue;
				
				tpl = new tplr.PlainTemplate();
				jElems = data[name].elems;
				for( ; i < jElems.length; ++i )
				{
					elems.push( new tplr.Element(
						jElems[i].prePos, 
						jElems[i].sufPos, 
						jElems[i].matchOpPos
					));
				}
				
				tpl.init( data[name].src, elems );
				this._templates[name] = tpl;
			}
			templates = this.getMultFromCache(requiredNames);
			
			if( callback )
				callback(templates, requiredNames);
		},
		getMultFromCache: function(names) {
			var templates = {}, i = 0;
			for( ; i < names.length; ++i ) {
				templates[ names[i] ] = this.getFromCache( names[i] );
			}
			return templates;
		},
		getFromCache: function(name) {
			if( this._templates.hasOwnProperty(name) )
				return this._templates[name];
			else
				throw new Error("Cannot get template '" + name + "' from cache!")
		},
		getTemplater: function(name) {
			var tpl = this._templates[name];
			if( tpl )
				return new tplr.PlainTemplater(tpl);
			else
				throw new Error( "There is no template in cache!" );
		}
	});
})();