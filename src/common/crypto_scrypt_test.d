module webtank.common.crypto_scrypt_benchmark;

import std.stdio, std.datetime, std.file, std.conv, std.base64;

pragma(lib, "/usr/local/lib/libtarsnap.a");

import webtank.common.crypto_scrypt;

uint N = 1024;
uint r = 8;
uint p = 1;
uint dkLen = 72;

uint iterNum = 500;
immutable fileName = "scrypt_test.txt";

void main()
{	
	
	string[string] keyPairs = [
		"": "",
		"Я пошёл есть суп с колбасками": "Ну и жри иди!",
		"cat": "dog",
		"Муха села на варенье - вот и всё стихотворенье": "Тут и сказочке конец!"
	];
	
	append( fileName, "\r\nScrypt function test...\r\n"  );
	append( fileName, "Scrypt params are:  N=" ~ N.to!string 
		~ ", r=" ~ r.to!string 
		~ ", p=" ~ p.to!string 
		~ ", dkLen=" ~ dkLen.to!string ~ "\r\n" 
	);
	
	ubyte[] hash;
	hash.length = dkLen;
	
	foreach( password, salt; keyPairs )
	{
		append( fileName, "Calculating Scrypt KDF for pair:\r\n");
		append( fileName, "  password=\"" ~ password ~ "\", " ~ password.length.to!string ~ " bytes\r\n" );
		append( fileName, "  salt=\"" ~ salt ~ "\", " ~ salt.length.to!string ~ " bytes\r\n" );
		
		auto time = Clock.currTime();
		for( uint i = 0; i < iterNum; i++ )
		{	crypto_scrypt( 
				cast(ubyte*) password.ptr, salt.length, 
				cast(ubyte*) salt.ptr, salt.length, 
				N, r, p, 
				hash.ptr, hash.length
			);
			
		}
		auto oneKeyHashTime = (Clock.currTime() - time) / iterNum;
		
		append( fileName, "KDF executed " ~ iterNum.to!string ~ " times using " ~ oneKeyHashTime.toString() ~ " per hash. Base64 encoded value is:\r\n" );
		append( fileName, Base64.encode( hash ) ~ "\r\n" );
	}
	
		
}

