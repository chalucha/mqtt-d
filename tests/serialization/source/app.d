import mqttd.messages;
import mqttd.ranges;
import mqttd.serialization;

import std.datetime;
import std.conv;
import std.array;
import std.stdio;

void withMy() {
    auto con = Connect();
    con.clientIdentifier = "testclient";
    con.flags.userName = true;
    con.userName = "user";
	
	auto buffer = appender!(ubyte[]);
	auto wr = writer(buffer);
	wr.serialize(con);
	
	auto data = reader(buffer.data);
    auto con2 = deserialize!Connect(data);
    assert(con == con2);
}


void main() {
    auto results = benchmark!(withMy)(1_000_000);
    writeln("My:  ", to!Duration(results[0]));
}