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
	},
};

var __hasProp = {}.hasOwnProperty;
var __extends = function(child, parent) {
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
};

webtank.WClass = new (function(_super) {
	function WClass(cssBlockName) {
		this.cssBlockName = cssBlockName;
		this._events = {};
	}
	
	WClass.prototype.$el = function(selector) {
		var 
			self = this,
			elems;
		
		if( selector.indexOf(".b-") !== -1 )
			throw new Error("Block selectors are not allowed!!!");
		
		elems = this.elems.filter(selector);
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
	};

	WClass.prototype.$on = function() {
		return $(this).on.apply($(this), arguments);
	};
	
	WClass.prototype.$off = function() {
		return $(this).off.apply($(this), arguments);
	};
	
	WClass.prototype.$trigger = function() {
		return $(this).trigger.apply($(this), arguments);
	};
	
	WClass.prototype.$triggerHandler = function() {
		return $(this).triggerHandler.apply($(this), arguments);
	};
	
	WClass.prototype.__parseSelector = function(selector)
	{
		var newSelector = selector;
		if( selector.indexOf(".b-") !== -1 )
			throw new Error("Block selectors are not allowed!!!");
		
		blockName = ( this.cssBlockName == null || this.cssBlockName.length == 0 ) ? this.elems.selector : this.cssBlockName;

		newSelector = selector.split(".e-").join(blockName + ".e-");
		
		return newSelector;
	}
	
	return WClass;
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
	Record: function() {
		var dctl = webtank.datctrl;
		//Создаём Record
		return {
			_fmt: null, //Формат записи (RecordFormat)
			_d: [], //Данные (массив)
			//Метод получения значения из записи по имени поля
			get: function(index) {
				if( webtank.isUnsigned(index) )
				{	//Вдруг там массив - лучше выдать копию
					return webtank.deepCopy( this._d[ index ] );
				}
				else
				{	//Вдруг там массив - лучше выдать копию
					return webtank.deepCopy( this._d[ this._fmt.getIndex(index) ] );
				}
			},
			getLength: function() {
				return this._d.length;
			},
			getFormat: function() {
				return webtank.deepCopy( this._fmt );
			},
			getKey: function() {
				return this._d[ this._fmt._keyFieldIndex ];
			},
			getKeyFieldIndex: function() {
				return this._fmt._keyFieldIndex;
			},
			set: function() {
				
			}
		};
	},
	//
	RecordSet: function() {
		var
			dctl = webtank.datctrl;
		//Создаём RecordSet
		return {
			_fmt: null, //Формат записи (RecordFormat)
			_d: [], //Данные (двумерный массив)
			_recIndex: 0,
			_indexes: {},
			//Возращает след. запись или null, если их больше нет
			next: function() {
				if( this._recIndex >= this._d.length )
					return null;
				else {
					var rec = new dctl.Record();
					rec._d = webtank.deepCopy( this._d[this._recIndex] );
					rec._fmt = webtank.deepCopy( this._fmt );
					this._recIndex++;
					return rec;
				}
			},
			//Возвращает true, если есть ещё записи, иначе - false
			hasNext: function() {
				return (this._recIndex < this._d.length);
			},
			//Сброс итератора на начало
			rewind: function() {
				this._recIndex = 0;
			},
			getFormat: function()
			{	return webtank.deepCopy(this._fmt);
			},
			//Возвращает количество записей в наборе
			getLength: function() {
				return this._d.length;
			},
			//Возвращает запись по ключу
 			getRecord: function(key) {
				if( this._indexes[key] )
					return this.getRecordAt( this._indexes[key] )
				else
					return null;
 			},
			//Возвращает запись по порядковому номеру index
			getRecordAt: function(index) {
				var rec = new dctl.Record();
				rec._d = webtank.deepCopy( this._d[this.index] );
				rec._fmt = webtank.deepCopy( this._fmt );
			},
			//Возвращает значение первичного ключа по порядковому номеру index
			getKey: function(index) {
				return this._d[ this._fmt._keyFieldIndex ][index];
			},
			//Возвращает true, если в наборе имеется запись с ключом key, иначе - false
			hasKey: function(key) {
				if( this._indexes[key] === undefined )
					return false;
				else
					return true;
			},
			//Возвращает порядковый номер поля первичного ключа в наборе записей
			getKeyFieldIndex: function() {
				return this._fmt._keyFieldIndex;
			},
			//Добавление записи rec в набор записей
			append: function(rec) {
				if( this._fmt.equals(rec._fmt) )
				{	this._indexes[ rec.getKey() ] = this._d.length;
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
			}
		};
	},
	RecordFormat: function() {
		var 
			dctl = webtank.datctrl;
		//Создаём формат записи
		return {
			_f: [],
			_indexes: {},
			_keyFieldIndex: 0,
			//Функция расширяет текущий формат, добавляя к нему format
			extend: function(format) {
				for( var i=0; i<format._f.length; i++ )
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
			}
		}
	},
	//трансформирует JSON в Record или RecordSet
	fromJSON: function(json) {
		var 
			dctl = webtank.datctrl,
			jsonObj = json;
		
		if( jsonObj.t === "record" || jsonObj.t === "recordset" )
		{	var 
				fmt = new dctl.RecordFormat(),
				rs,
				rec,
				i;
			
			fmt._f = jsonObj.f;
			fmt._keyFieldIndex = jsonObj.kfi || 0;
			
			for( i = 0; i < jsonObj.f.length; i++ )
				fmt._indexes[ jsonObj.f[i].n ] = i;
				
			if( jsonObj.t === "record" )
			{	rec = new dctl.Record();
				rec._fmt = fmt;
				rec._d = jsonObj.d;
				return rec;
			}
			else if( jsonObj.t === "recordset" )
			{	rs = new dctl.RecordSet(),
				
				rs._fmt = fmt;
				rs._d = jsonObj.d;
				for( i = 0; i < jsonObj.d.length; i++ )
					rs._indexes[ jsonObj.d[i][fmt._keyFieldIndex] ] = i;
					
				return rs;
			}
		}
			
	}
}

