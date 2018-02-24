module webtank.net.service.endpoint;

struct EndPoint
{
private:
	string _uri;
	string _serviceName;
	string _name;
	void _test() {
		if( isNull ) {
			throw new Exception(`Access to empty endpoint!!!`);
		}
	}
public:
	bool isNull() @property {
		return !_uri.length || !_serviceName.length  || !_name;
	}
	string URI() @property {
		_test(); return _uri;
	}
	string serviceName() @property {
		_test(); return _serviceName;
	}
	string name() @property {
		_test(); return _name;
	}
}