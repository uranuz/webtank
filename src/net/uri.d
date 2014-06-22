module webtank.net.uri;

import std.string, std.exception, std.utf;

import std.range,
		std.string,
		std.ascii,
		std.socket;

/// Exception thrown when an URI doesn't parse.
class URIException : Exception
{	this(string msg, string file = __FILE__, size_t line = __LINE__)  pure nothrow{
		super(msg, file, line);
	}
}

/**

	An attempt at implementing URI (RFC 3986).

All constructed URI are valid and normalized.
Bugs:
$(UL
	$(LI Separate segments in parsed form.)
	$(LI Relative URL combining.)
	$(LI . and .. normalization.)
)

Alternative:
	Consider using $(WEB vibed.org,vibe.d) if you need something better.
*/
struct URI
{
	public
	{
		enum HostType
		{
				NONE,
				REG_NAME, /// Host has a registered name.
				IPV4,     /// Host has an IPv4
				IPV6,     /// Host has an IPv6
				IPVFUTURE /// Unknown yet scheme.
		}

		/// Creactes an URI from an input range, throws if invalid.
		/// Input should be an ENCODED url range.
		/// Throws: $(D URIException) if the URI is invalid.
		this(T)(T input, bool isStrictParser = false, bool isRawURI = true) if (isForwardRange!T)
		{
				_scheme = null;
				_hostType = HostType.NONE;
				_rawHost = null;
				_port = 0;
				_rawUserInfo = null;
				_rawPath = null;
				_rawQuery = null;
				_rawFragment = null;
				_isStrictParser = isStrictParser;
				auto inp = isRawURI ? input : encodeURI(input);
				parseURI( inp );
		}

		/// Checks URI validity.
		/// Returns: true if input is valid.
		static bool isValid(T)(T input) /* pure */ nothrow
		{
			try
			{
				try
				{
					URI uri = URI(input);
					return true;
				}
				catch (URIException e)
				{
					return false;
				}
			}
			catch (Exception e)
			{
				assert(false); // came here? Fix the library by writing the missing catch-case.
			}
		}

		// getters and setters for normalized URI components

		/// Returns: URI scheme, guaranteed not null.
		string scheme() @property pure const nothrow
		{	return _scheme;
		}

		void scheme(string value) @property pure nothrow
		{	_scheme = value;
		}

		/// Returns: Host name, or null if not available.
		string host() @property pure const /+nothrow+/
		{	return decodeURIHost(_rawHost);
		}

		void host(string value) @property pure /+nothrow+/
		{	_rawHost = encodeURIHost(value);
		}

		/// Returns: Host name, or null if not available.
		string rawHost() @property pure const nothrow
		{	return _rawHost;
		}

		void rawHost(string value) @property pure nothrow
		{	_rawHost = value;
		}

		/// Returns: Host type (HostType.NONE if not available).
		HostType hostType() @property pure const nothrow
		{
			return _hostType;
		}

		/**
			* Returns: port number.
			* If none is provided by the URI, return the default port for this scheme.
			* If the scheme isn't recognized, return 0.
			*/
		ushort port() @property pure const nothrow
		{
			if (_port != 0)
				return _port;

			foreach (ref e; knownSchemes)
				if (e.scheme == _scheme)
					return e.defaultPort;

			return 0;
		}

		void port(ushort value) @property pure nothrow
		{	_port = value;
		}

		/// Returns: User-info part of the URI, or null if not available.
		string userInfo() @property pure const /+nothrow+/
		{	return decodeURIUserInfo(_rawUserInfo); }

		/// Returns: User-info part of the URI, or null if not available.
		void userInfo(string value) @property pure /+nothrow+/
		{	_rawUserInfo = encodeURIUserInfo(value); }

		/// Returns: User-info part of the URI, or null if not available.
		string rawUserInfo() @property pure const nothrow
		{	return _rawUserInfo; }

		/// Returns: User-info part of the URI, or null if not available.
		void rawUserInfo(string value) @property pure nothrow
		{	_rawUserInfo = value; }

		/// Returns: Path part of the URI, never null, can be the empty string.
		string rawPath() @property pure const nothrow
		{	return _rawPath;
		}

		void rawPath(string value) @property pure nothrow
		{	_rawPath = value;
		}

		/// Returns: Path part of the URI, never null, can be the empty string.
		string path() @property pure const /+nothrow+/
		{	return  decodeURIPath(_rawPath);
		}

		void path(string value) @property pure /+nothrow+/
		{	_rawPath = encodeURIPath(value);
		}

// 		string[] segments() @property pure
// 		{}

		string rawQuery() @property pure const nothrow
		{	return _rawQuery;
		}

		void rawQuery(string value) @property pure nothrow
		{	_rawQuery = value;
		}

		/// Returns: Query part of the URI, or null if not available.
		string query() @property pure const /+nothrow+/
		{	return decodeURIQueryOrFragment(_rawQuery);
		}

		void query(string value) @property pure /+nothrow+/
		{	_rawQuery = encodeURIQueryOrFragment(value);
		}

		/// Returns: Fragment part of the URI, or null if not available.
		string rawFragment() @property pure const nothrow
		{	return _rawFragment;
		}

		void rawFragment(string value) @property pure nothrow
		{	_rawFragment = value;
		}

		/// Returns: Fragment part of the URI, or null if not available.
		string fragment() @property pure const /+nothrow+/
		{	return decodeURIQueryOrFragment(_rawFragment);
		}

		void fragment(string value) @property pure /+nothrow+/
		{	_rawFragment = encodeURIQueryOrFragment(value);
		}

		/// Returns: Authority part of the URI.
		string rawAuthority() @property pure const nothrow
		{
			if( rawHost.length == 0 )
				return "";

			string res = "";
			if( rawUserInfo.length > 0 )
				res ~= rawUserInfo ~ "@";

			res ~= rawHost;

			if( port != 0 )
				res ~= ":" ~ itos(port);

			return res;
		}

		/// Returns: Authority part of the URI.
		string authority() @property pure const /+nothrow+/
		{
			if( host.length == 0 )
				return "";

			string res = "";
			if( userInfo.length > 0 )
				res ~= userInfo ~ "@";

			res ~= host;

			if( port != 0 )
			{	bool isDefaultPort = false;
				foreach( e; knownSchemes )
				{	if( e.defaultPort == port && scheme == e.scheme )
					{	isDefaultPort = true;
						break;
					}
				}
				if( !isDefaultPort )
					res ~= ":" ~ itos(port);
			}
				

			return res;
		}

		void authority(string value) @property /+pure+/
		{	//Clearing authority data
			_rawUserInfo = null;
			_rawHost = null;
			_port = 0;
			string encodedValue = encodeURIHost(value);
			parseAuthority( encodedValue );
		}

		void rawAuthority(string value) @property /+pure+/
		{	//Clearing authority data
			_rawUserInfo = null;
			_rawHost = null;
			_port = 0;
			parseAuthority( value );
		}

		/// Resolves URI host name.
		/// Returns: std.socket.Address from the URI.
		Address resolveAddress()
		{
			final switch(_hostType)
			{
				case HostType.REG_NAME:
				case HostType.IPV4:
					return new InternetAddress(_rawHost, cast(ushort)port());

				case HostType.IPV6:
					return new Internet6Address(_rawHost, cast(ushort)port());

				case HostType.IPVFUTURE:
				case HostType.NONE:
					throw new URIException("Cannot resolve such host");
			}
		}

		/// Returns: Pretty string representation.
		string toString() const
		{
			string res;

			if( !scheme.empty )
				res ~= scheme ~ ":";

			if ( !host.empty )
				res = res ~ "//" ~ authority;

			res ~= path;

			if( !query.empty )
				res = res ~ "?" ~ query;
			if( !fragment.empty )
				res = res ~ "#" ~ fragment;
			return res;
		}

		string toRawString() const
		{	string res;

			if( !scheme.empty )
				res ~= scheme ~ ":";

			if ( !rawHost.empty )
				res = res ~ "//" ~ rawAuthority;

			res ~= rawPath;

			if( !rawQuery.empty )
				res = res ~ "?" ~ rawQuery;
			if( !rawFragment.empty )
				res = res ~ "#" ~ rawFragment;
			return res;
		}

		/// Semantic comparison of two URIs.
		/// They are equals if they have the same normalized string representation.
		bool opEquals(U)(U other) pure const nothrow if (is(U : FixedPoint))
		{	return value == other.value;
		}
	}

	private
	{
		// normalized URI components
		string _scheme;     // never null, never empty
		string _rawUserInfo;   // can be null
		HostType _hostType; // what the hostname string is (NONE if no host in URI)
		string _rawHost;   // null if no authority in URI
		ushort _port;          // 0 if no port in URI
		string _rawPath;       // never null, bu could be empty
		string _rawQuery;      // can be null
		string _rawFragment;   // can be null

		bool _isStrictParser;

		// URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
		void parseURI(T)(ref T input)
		{	 auto inputOrigin = input[];
			_scheme = toLower(parseScheme(input));
			//consume(input, ':');
			if( _scheme.empty )
				input = inputOrigin;

			parseHierPart(input);

			if (input.empty)
				return;

			char c = popChar(input);

			if (c == '?')
			{
				_rawQuery = parseQuery(input);

				if (input.empty)
					return;

				c = popChar(input);
			}

			if (c == '#')
			{
				_rawFragment = parseFragment(input);
			}

			if (!input.empty)
				throw new URIException("unexpected characters at end of URI");
		}

		string parseScheme(T)(ref T input)
		{
// 			writeln("parseScheme input: ", input);
			string result = "";
			char c = peekChar(input);

			if( !isAlpha(c) )
				return "";
				//throw new URIException("expected alpha character in URI scheme");

			input.popFront();
			result ~= c;

			while(!input.empty)
			{
				c = peekChar(input);

				if (isAlpha(c) || isDigit(c) || "+-.".contains(c))
				{
					result ~= c;
					input.popFront();
				}
				else if( c == ':' )
				{	input.popFront();
					return result;
				}
				else
					return "";
			}

			if( input.empty )
				return "";
			assert(0);
		}

		// hier-part   = "//" authority path-abempty
		//             / path-absolute
		//             / path-rootless
		//             / path-empty
		void parseHierPart(T)(ref T input)
		{
// 			writeln("parseHierPart input: ", input);
			if (input.empty())
				return; // path-empty

			char c = peekChar(input);
			if (c == '/')
			{
				T sinput = input.save;
				input.popFront();

				if (!input.empty() && peekChar(input) == '/')
				{
					consume(input, '/');
					parseAuthority(input); //Look at non-struct parsing after change
					_rawPath = parseAbEmpty(input);
				}
				else
				{
					input = sinput.save;
					_rawPath = parsePathAbsolute(input);
				}
			}
			else
			{	if( !_isStrictParser && _scheme.empty )
				{	//Non-strict parsing of "Suffix Reference""
					bool isValidAuthority = true;
					auto temp = input.save();
					try {
						parseAuthority(input);
						_rawPath = parseAbEmpty(input);
					}
					catch( URIException e )
					{	isValidAuthority = false; }

					if( isValidAuthority && _hostType == HostType.REG_NAME )
					{	import std.algorithm : count;
						auto pointCount = _rawHost.count(".");
						//Consider that correct names are of 2nd level or higher
						if( _rawHost.back == '.' )
							isValidAuthority = ( pointCount >= 2 );
						else
							isValidAuthority = ( pointCount >= 1 );
					}
					
					if( !isValidAuthority ) //Not correct authority
					{	_rawUserInfo = null;
						_rawHost = null;
						_port = 0;
						_hostType = HostType.NONE;
						parsePathRootless(temp); 
					}
				}
				else
					_rawPath = parsePathRootless(input);
			}
		}

		// authority   = [ userinfo "@" ] host [ ":" port ]
		void parseAuthority(T)(ref T input)
		{		/+writeln("parseAuthority input: ", input);+/
			// trying to parse user
			T uinput = input.save;
			try
			{
				_rawUserInfo = parseUserinfo(input);
				consume(input, '@');
			}
			catch(URIException e)
			{
				// no user name in URI
				_rawUserInfo = null;
				input = uinput.save;
			}

			parseHost(input, _rawHost, _hostType);

			if (!empty(input) && peekChar(input) == ':')
			{
				consume(input, ':');
				_port = parsePort(input);
			}
		}
		
		string parsePcharString(T)(ref T input, string allowedSpecChars = null)
		{
			string res = "";

			while(!input.empty)
			{
				char c = peekChar(input);

				if( isUnreserved(c) || isSubDelim(c) || c == '%' || allowedSpecChars.contains(c) )
					res ~= popChar(input);
				else
					break;
			}
			return res;
		}


		void parseHost(T)(ref T input, out string res, out HostType hostType)
		{	/+writeln("parseHost input: ", input);+/
			char c = peekChar(input);
			if (c == '[')
				parseIPLiteral(input, res, hostType);
			else
			{
				T iinput = input.save;
				try
				{
					hostType = HostType.IPV4;
					res = parseIPv4Address(input);
				}
				catch (URIException e)
				{
					input = iinput.save;
					hostType = HostType.REG_NAME;
					res = toLower(parseRegName(input));
				}
			}
		}

		void parseIPLiteral(T)(ref T input, out string res, out HostType hostType)
		{
			consume(input, '[');
			if (peekChar(input) == 'v')
			{
				hostType = HostType.IPVFUTURE;
				res = parseIPv6OrFutureAddress(input);
			}
			else
			{
				hostType = HostType.IPV6;
				string ipv6 = parseIPv6OrFutureAddress(input);

				// validate and expand IPv6 (for normalizaton to be effective for comparisons)
				try
				{
					ubyte[16] bytes = Internet6Address.parse(ipv6);
					res = "";
					foreach (i ; 0..16)
					{
							if ((i & 1) == 0 && i != 0)
								res ~= ":";
							res ~= format("%02x", bytes[i]);
					}
				}
				catch(SocketException e)
				{
					// IPv6 address did not parse
					throw new URIException(e.msg);
				}
			}
			consume(input, ']');
		}

		string parseIPv6OrFutureAddress(T)(ref T input)
		{
			string res = "";
			while (peekChar(input) != ']')
				res ~= popChar(input);
			return res;
		}

		string parseIPv4Address(T)(ref T input)
		{
			int a = parseDecOctet(input);
			consume(input, '.');
			int b = parseDecOctet(input);
			consume(input, '.');
			int c = parseDecOctet(input);
			consume(input, '.');
			int d = parseDecOctet(input);
			return format("%s.%s.%s.%s", a, b, c, d);
		}

		// dec-octet     = DIGIT                 ; 0-9
		//               / %x31-39 DIGIT         ; 10-99
		//               / "1" 2DIGIT            ; 100-199
		//               / "2" %x30-34 DIGIT     ; 200-249
		//               / "25" %x30-35          ; 250-255
		int parseDecOctet(T)(ref T input)
		{
			int res = popDigit(input);

			if (!input.empty && isDigit(peekChar(input)))
			{
				res = 10 * res + popDigit(input);

				if (!input.empty && isDigit(peekChar(input)))
					res = 10 * res + popDigit(input);
			}

			if (res > 255)
				throw new URIException("out of range number in IPv4 address");

			return res;
		}

		// query         = *( pchar / "/" / "?" )
		string parseQuery(T)(ref T input)
		{
			return parsePcharString(input, ":@/?");
		}

		// fragment      = *( pchar / "/" / "?" )
		string parseFragment(T)(ref T input)
		{
			return parsePcharString(input, ":@/?");
		}

		// userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
		string parseUserinfo(T)(ref T input)
		{	/+writeln("parseUserinfo input: ", input);+/
			return parsePcharString(input, ":");
		}

		// reg-name      = *( unreserved / pct-encoded / sub-delims )
		string parseRegName(T)(ref T input)
		{
			return parsePcharString(input);
		}

		// port          = *DIGIT
		ushort parsePort(T)(ref T input)
		{
			ushort res = 0;

			while(!input.empty)
			{
				char c = peekChar(input);
				if (!isDigit(c))
					break;
				res = cast(ushort) ( res * 10u + popDigit(input) );
			}
			return res;
		}

		// segment       = *pchar
		// segment-nz    = 1*pchar
		// segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
		string parseSegment(T)(ref T input, bool allowZero, bool allowColon)
		{
			string res = parsePcharString( input, ( allowColon ? ":@" : "@" ) );
			if (!allowZero && res == "")
				throw new URIException("expected a non-zero segment in URI");
			return res;
		}

		// path-abempty  = *( "/" segment )
		string parseAbEmpty(T)(ref T input)
		{	/+writeln("parseAbEmpty input: ", input);+/
			string res = "";
			while (!input.empty)
			{
				if (peekChar(input) != '/')
					break;
				consume(input, '/');
				res = res ~ "/" ~ parseSegment(input, true, true);
			}
			return res;
		}

		// path-absolute = "/" [ segment-nz *( "/" segment ) ]
		string parsePathAbsolute(T)(ref T input)
		{	/+writeln("parsePathAbsolute input: ", input);+/
			consume(input, '/');
			string res = "/";

			try
			{
				res ~= parseSegment(input, false, true);
			}
			catch(URIException e)
			{
				return res;
			}

			res ~= parseAbEmpty(input);
			return res;
		}

		string parsePathNoSlash(T)(ref T input, bool allowColonInFirstSegment)
		{	/+writeln("parsePathNoSlash input: ", input);+/
			string res = parseSegment(input, false, allowColonInFirstSegment);
			res ~= parseAbEmpty(input);
			return res;
		}

		// path-noscheme = segment-nz-nc *( "/" segment )
		string parsePathNoScheme(T)(ref T input)
		{	/+writeln("parsePathNoScheme input: ", input);+/
			return parsePathNoSlash(input, false);
		}

		// path-rootless = segment-nz *( "/" segment )
		string parsePathRootless(T)(ref T input)
		{	/+writeln("parsePathRootless input: ", input);+/
			return parsePathNoSlash(input, true);
		}
	}
}

private pure
{
	bool isMaybeHostname(T)(T input)
	{
		

	}

	bool contains(string s, char c) nothrow
	{
		foreach(char sc; s)
			if (c == sc)
				return true;
		return false;
	}

	bool isAlpha(char c) nothrow
	{
		return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
	}

	bool isDigit(char c) nothrow
	{
		return c >= '0' && c <= '9';
	}

	bool isHexDigit(char c) nothrow
	{
		return hexValue(c) != ushort.max;
	}

	bool isUnreserved(char c) nothrow
	{
		return isAlpha(c) || isDigit(c) || "-._~".contains(c);
	}

	bool isReserved(char c) nothrow
	{
		return isGenDelim(c) || isSubDelim(c);
	}

	bool isGenDelim(char c) nothrow
	{
		return ":/?#[]@".contains(c);
	}

	bool isSubDelim(char c) nothrow
	{
		return "!$&'()*+,;=".contains(c);
	}

	ushort hexValue(char c) nothrow
	{
		if( isDigit(c) )
				return cast(ushort)(c - '0');
		else if (c >= 'a' && c <= 'f')
				return cast(ushort)(c - 'a' + 10);
		else if (c >= 'A' && c <= 'F')
				return cast(ushort)(c - 'A' + 10);
		else
				return ushort.max;
	}

	// peek char from input range, or throw
	char peekChar(T)(ref T input)
	{
		if (input.empty())
				throw new URIException("expected character");

		dchar c = input.front;

		if (cast(int)c >= 127)
				throw new URIException("US-ASCII character expected");

		return cast(char)c;
	}

	// pop char from input range, or throw
	char popChar(T)(ref T input)
	{
		char result = peekChar(input);
		input.popFront();
		return result;
	}

	ushort popDigit(T)(ref T input)
	{
		char c = popChar(input);
		if (!isDigit(c))
				throw new URIException("expected digit character");
		return hexValue(c);
	}

	void consume(T)(ref T input, char expected)
	{
		char c = popChar(input);
		if (c != expected)
				throw new URIException("expected '" ~ c ~ "' character");
	}

	string itos(int i) pure nothrow
	{
		string res = "";
		do
		{
				res = ('0' + (i % 10)) ~ res;
				i = i / 10;
		} while (i != 0);
		return res;
	}

	struct KnownScheme
	{	string scheme;
		ushort defaultPort;
	}

	enum knownSchemes =
	[
		KnownScheme("ftp", 21),
		KnownScheme("sftp", 22),
		KnownScheme("telnet", 23),
		KnownScheme("smtp", 25),
		KnownScheme("gopher", 70),
		KnownScheme("http", 80),
		KnownScheme("nntp", 119),
		KnownScheme("https", 443)
	];

}

unittest
{

	{
		string s = "HTTP://machin@fr.wikipedia.org:80/wiki/Uniform_Resource_Locator?Query%20Part=4#fragment%20part";
		assert(URI.isValid(s));
		auto uri = new URI(s);
		assert(uri.scheme == "http");
		assert(uri.userInfo == "machin");
		assert(uri.hostName == "fr.wikipedia.org");
		assert(uri.port == 80);
		assert(uri.authority == "machin@fr.wikipedia.org:80");
		assert(uri.path == "/wiki/Uniform_Resource_Locator");
		assert(uri.query == "Query Part=4");
		assert(uri.fragment == "fragment part");
	}

	// host tests
	{
		assert((new URI("http://truc.org")).hostType == URI.HostType.REG_NAME);
		assert((new URI("http://127.0.0.1")).hostType == URI.HostType.IPV4);
		assert((new URI("http://[2001:db8::7]")).hostType == URI.HostType.IPV6);
		assert((new URI("http://[v9CrazySchemeFromOver9000year]")).hostType == URI.HostType.IPVFUTURE);
	}

	auto wellFormedURIs =
	[
		"ftp://ftp.rfc-editor.org/in-notes/rfc2396.txt",
		"mailto:Quidam.no-spam@example.com",
		"news:fr.comp.infosystemes.www.auteurs",
		"gopher://gopher.quux.org/",
		"http://Jojo:lApIn@www.example.com:8888/chemin/d/acc%C3%A8s.php?q=req&q2=req2#signet",
		"ldap://[2001:db8::7]/c=GB?objectClass?one",
		"mailto:John.Doe@example.com",
		"tel:+1-816-555-1212",
		"telnet://192.0.2.16:80/",
		"urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
		"about:",
	];

	foreach (wuri; wellFormedURIs)
	{	bool valid = URI.isValid(wuri);
		assert(valid);
	}
}

immutable(char[]) hexChars = "0123456789ABCDEF";

template encodeURICustom(string allowedSpecChars = null, bool isFormEncoding = false)
{
	static assert( !allowedSpecChars.contains('%'), "% sign must have the meaning of percent code prefix!!!" );
	
	string encodeURICustom(T : string)(T source) pure
	{	
		//import std.utf : toUTF8;
		import std.array : appender;

		//auto source = toUTF8(src);
		
		auto result = appender!string();
		result.reserve(source.length);

		foreach( i, c; source )
		{	//writeln( source[i..$] );
			if( c == ' ' )
			{	static if( isFormEncoding )
					result ~= '+';
			}
			else if( isUnreserved(c) || allowedSpecChars.contains(c) )
			{	result ~= c; }
			else
			{	result ~= [ '%', hexChars[ c >> 4 ], hexChars[ c & 0x0F ] ]; }
		}
		return result.data;
	}
}

template decodeURICustom(string allowedSpecChars = null, bool isFormEncoding = false)
{
	static assert( !allowedSpecChars.contains('%'), "% sign must have the meaning of percent code prefix!!!" );
	
	string decodeURICustom(T : string)(T source) pure
	{
		//import std.utf : toUTF8;
		import std.array : appender;

		//auto source = toUTF8(src);
		
		auto result = appender!string();
		result.reserve(source.length);

		for( size_t i = 0; i < source.length; i++ )
		{
			auto c = source[i];
			if( c == '+' )
			{
				static if( isFormEncoding )
					result ~= ' ';
			}
			else if( isUnreserved(c) || allowedSpecChars.contains(c) )
			{	result ~= c; }
			else if( c == '%' )
			{
				if( i + 2 < source.length )
				{	if( isHexDigit(source[i+1]) && isHexDigit(source[i+2]) )
					{	result ~= cast(char)( ( hexValue(source[i+1]) << 4 ) + ( hexValue(source[i+2])  ) );

						i += 2;
					}
					else
						throw new Exception( "Invalid percent encoded sequence!!!" );
				}
				else
					throw new Exception( "Invalid percent encoded sequence!!!" );
			}
			else
				throw new Exception( "Not allowed character found in URI encoded string!!!" );
		}
		return result.data;
	}
}


// reg-name    = *( unreserved / pct-encoded / sub-delims )
// host        = IP-literal / IPv4address / reg-name
///Декодирует имя хоста идентификатора ресурса из URI кодировки
alias decodeURICustom!("!$&'()*+,;=") decodeURIHost;
///Кодирует имя хоста идентификатора ресурса в URI кодировку
alias encodeURICustom!("!$&'()*+,;=") encodeURIHost;

///Декодирует путь идентификатора ресурса из URI кодировки
alias decodeURICustom!("!$&'()*+,;=:@/") decodeURIPath;
///Кодирует путь идентификатора ресурса в URI кодировку
alias encodeURICustom!("!$&'()*+,;=:@/") encodeURIPath;

// userinfo    = *( unreserved / pct-encoded / sub-delims / ":" )
///Декодирует информацию о пользователе идентификатора ресурса из URI кодировки
alias decodeURICustom!("!$&'()*+,;=:") decodeURIUserInfo;
///Кодирует информацию о пользователе идентификатора ресурса в URI кодировку
alias encodeURICustom!("!$&'()*+,;=:") encodeURIUserInfo;

// query       = *( pchar / "/" / "?" )
// fragment    = *( pchar / "/" / "?" )
///Декодирует строку запроса или фрагмент идентификатора ресурса из URI кодировки
alias decodeURICustom!("!$&'()*+,;=:@/?") decodeURIQueryOrFragment;
///Кодирует строку запроса или фрагмент идентификатора ресурса в URI кодировку
alias encodeURICustom!("!$&'()*+,;=:@/?") encodeURIQueryOrFragment;

///Декодирует строку запроса или фрагмент идентификатора ресурса из URI кодировки
alias decodeURICustom!("!$&'()*+,;=:@/?", true) decodeURIFormQuery;
///Кодирует строку запроса или фрагмент идентификатора ресурса в URI кодировку
alias encodeURICustom!("!$&'()*+,;=:@/?", true) encodeURIFormQuery;

///Декодирует произвольную подстроку из URI кодировки
alias decodeURICustom!("") decodeURIComponent;
///Кодирует произвольную подстроку в URI кодировку
alias encodeURICustom!("") encodeURIComponent;

// unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
// sub-delims  = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
// gen-delims    = ":" / "/" / "?" / "#" / "[" / "]" / "@"
// pct-encoded = "%" HEXDIG HEXDIG
///Декодирует полный идентификатор из URI кодировки
alias decodeURICustom!("!$&'()*+,;=:/?#[]@") decodeURI;
///Кодирует полный идентификатор в URI кодировку
alias encodeURICustom!("!$&'()*+,;=:/?#[]@") encodeURI;
