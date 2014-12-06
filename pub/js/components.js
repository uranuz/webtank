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
	}
	
	WClass.prototype.$el = function(elemSelector) {
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
	//трансформирует JSON в Record или RecordSet
	fromJSON: function(json) {
		var 
			dctl = webtank.datctrl,
			jsonObj = json,
			kfi, fmt;
		
		if( jsonObj.t === "record" || jsonObj.t === "recordset" )
		{	
			kfi = jsonObj.kfi || 0;
			fmt = new dctl.RecordFormat({
				fields: jsonObj.f, 
				keyFieldIndex: kfi
			});
				
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
	}
};
webtank.datctrl.Record = new (function() {
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
	
	//Метод получения значения из записи по имени поля
	Record.prototype.get = function(index, defaultValue) {
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
	};
	
	Record.prototype.getLength = function() {
		return this._d.length;
	};
	
	Record.prototype.copyFormat = function() {
		return this._fmt.copy();
	};
	
	Record.prototype.getKey = function() {
		return this._d[ this._fmt._keyFieldIndex ];
	};
	
	Record.prototype.getKeyFieldIndex = function() {
		return this._fmt._keyFieldIndex;
	};
	
	Record.prototype.set = function() {
		//Не используй меня. Я пустой!..
		//...или реализуй меня и используй
	};
	
	Record.prototype.getIsEmpty = function() {
		return !this._d.length && this._fmt.getIsEmpty();
	};
	
	Record.prototype.copy = function() {
		return new Record({
			format: this._fmt.copy(),
			data: webtank.deepCopy( this._d )
		});
	};
	
	return Record;
})();

webtank.datctrl.RecordSet = new (function() {
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
	
	//Возращает след. запись или null, если их больше нет
	RecordSet.prototype.next = function() {
		var rec = this.getRecordAt(this._recIndex);
		this._recIndex++;
		return rec;
	};
	
	//Возвращает true, если есть ещё записи, иначе - false
	RecordSet.prototype.hasNext = function() {
		return (this._recIndex < this._d.length);
	};

	//Сброс итератора на начало
	RecordSet.prototype.rewind = function() {
		this._recIndex = 0;
	};
	RecordSet.prototype.copyFormat = function()
	{	return this._fmt.copy();
	};
	
	//Возвращает количество записей в наборе
	RecordSet.prototype.getLength = function() {
		return this._d.length;
	};
	
	//Возвращает запись по ключу
	RecordSet.prototype.getRecord = function(key) {
		if( this._indexes[key] == null )
			return null;
		else
			return this.getRecordAt( this._indexes[key] );
	};
	
	//Возвращает запись по порядковому номеру index
	RecordSet.prototype.getRecordAt = function(index) {
		if( index < this._d.length )
			return new dctl.Record({
				format: this._fmt,
				data: this._d[index]
			});
		else
			return null;
	};
	
	//Возвращает значение первичного ключа по порядковому номеру index
	RecordSet.prototype.getKey = function(index) {
		return this._d[ this._fmt.getKeyFieldIndex() ][index];
	};
	
	//Возвращает true, если в наборе имеется запись с ключом key, иначе - false
	RecordSet.prototype.hasKey = function(key) {
		if( this._indexes[key] == null )
			return false;
		else
			return true;
	};
	
	//Возвращает порядковый номер поля первичного ключа в наборе записей
	RecordSet.prototype.getKeyFieldIndex = function() {
		return this._fmt.getKeyFieldIndex();
	};
	
	//Добавление записи rec в набор записей
	RecordSet.prototype.append = function(rec) {
		if( this.getIsEmpty || this._fmt.equals(rec._fmt) )
		{	
			if( this._fmt.getIsEmpty() )
				this._fmt = rec._fmt.copy();
			this._indexes[ rec.getKey() ] = this._d.length;
			this._d.push(rec._d);
		}
		else
			console.error("Формат записи не совпадает с форматом набора данных!!!");
	};
	
	RecordSet.prototype.remove = function(key) {
		var
			index = this._indexes[key];
		
		if( index !== undefined )
		{	this._d.splice(index, 1);
			this._reindex(index);
		}
		else
			console.error("Запись с ключом " + key + " не содержится в наборе данных!!!");
	};
	
	RecordSet.prototype._reindex = function(startIndex) {
		var
			i = 0,
			kfi = this.getKeyFieldIndex();
		
		this._indexes = {};
		
		for( ; i < this._d.length ; i++ )
			this._indexes[ this._d[i][ kfi ] ] = i;
	};
	
	RecordSet.prototype.getIsEmpty = function() {
		return !this._d.length && this._fmt.getIsEmpty();
	};
	
	RecordSet.prototype.copy = function() {
		return new dctl.RecordSet({
			format: this._fmt.copy(),
			data: webtank.deepCopy( this._d ),
			keyFieldIndex: this._keyFieldIndex
		});
	};
	
	return RecordSet;
})();

webtank.datctrl.RecordFormat = new (function() {
	var 
		dctl = webtank.datctrl;
	
	function RecordFormat(opts)
	{
		opts = opts || {}
		if( opts.fields instanceof Array ) 
		{
			this._f = opts.fields;
			this._keyFieldIndex = opts.keyFieldIndex? opts.keyFieldIndex : 0;
		}
		else
		{
			this._f = [];
			this._keyFieldIndex = 0;
		}
		
		this._reindex();
	}
	
	RecordFormat.prototype._reindex = function() {
		var key, i;
		this._indexes = {}
		for( i = 0; i < this._f.length; i++ )
		{
			key = this._f[i].n;
			if( key != null )
				this._indexes[key] = i;
		}
	};
	
	//Функция расширяет текущий формат, добавляя к нему format
	RecordFormat.prototype.extend = function(format) {
		for( var i = 0; i < format._f.length; i++ )
		{	this._f.push(format._f[i]);
			this._indexes[format.n] = format._f.length;
		}
	};
	
	//Получить индекс поля по имени
	RecordFormat.prototype.getIndex = function(name) {
		return this._indexes[name];
	};
	
	//Получить имя поля по индексу
	RecordFormat.prototype.getName = function(index) {
		return this._f[ index ].n;
	};
	
	//Получить тип поля по имени или индексу
	RecordFormat.prototype.getType = function(index) {
		if( webtank.isUnsigned(index) )
			return this._f[ index ].t;
		else
			return this._f[ this.getFieldIndex(index) ].t;
	};
	
	RecordFormat.prototype.getKeyFieldIndex = function() {
		return this._keyFieldIndex;
	};
	
	RecordFormat.prototype.equals = function(format) {
		return this._f.length === format._f.length;
	};
	
	RecordFormat.prototype.getIsEmpty = function() {
		return !this._f.length;
	};
	
	RecordFormat.prototype.copy = function() {
		return new dctl.RecordFormat({
			fields: webtank.deepCopy( this._f ),
			keyFieldIndex: this._keyFieldIndex
		});
	};
	
	return RecordFormat;
})();

