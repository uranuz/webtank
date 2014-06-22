module webtank.common.crypto_scrypt_benchmark;

import std.stdio, std.datetime, std.file, std.conv;

pragma(lib, "/usr/local/lib/libtarsnap.a");

import webtank.common.crypto_scrypt;

uint[] Ns = [ 4_096, 8_192, 16_384, 32_768, 65_536, 131_072, 262_144/+, 524_288, 1_048_576+/ ];
uint r = 8;
uint p = 1;
uint iterNum = 20;

uint[] bufSizes = [ /+48, 54,+/ 60, /+66, 72,+/ 78, 84, 90, 96, 102/+, 108, 114, 120, 126, 132, 138+/ ];

immutable fileName = "scrypt_express_benchmark_20.txt";

void main()
{
	string[string] dataPairs = [
		"": "",
		"dog": "cat",
		"гладиолус": "ананас"
	];
	
	auto f = File( fileName, "w" );
	f.close();
	
	foreach( pw, salt; dataPairs )
		runScryptBenchmark(pw, salt);

}

void runScryptBenchmark( const(char)[] password, const(char)[] salt )
{	append( fileName, "Starting benchmark for these input values\r\n" );
	append( fileName, "  password=\"" ~ password ~ "\"\r\n" );
	append( fileName, "  salt=\"" ~ salt ~ "\"\r\n" );
	foreach( N; Ns )
	{	foreach( bufSize; bufSizes )
		{	ubyte[] hash;
			hash.length = bufSize;
			
			auto time = Clock.currTime();
			for( uint i = 0; i < iterNum; i++ )
			{	crypto_scrypt( 
					cast(ubyte*) password.ptr, salt.length, 
					cast(ubyte*) salt.ptr, salt.length, 
					N, r, p, 
					hash.ptr, hash.length
				);
				
			}
			
			append( fileName, "Hashed with params N=" ~ N.to!string ~ ", bufSize=" ~ bufSize.to!string ~ " in " ~ (Clock.currTime() - time).toString() ~ "\r\n" );
		}
	}
	
	
}
