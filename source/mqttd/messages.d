﻿/**
 * 
 * /home/tomas/workspace/mqtt-d/source/message.d
 * 
 * Author:
 * Tomáš Chaloupka <chalucha@gmail.com>
 * 
 * Copyright (c) 2015 Tomáš Chaloupka
 * 
 * Boost Software License 1.0 (BSL-1.0)
 * 
 * Permission is hereby granted, free of charge, to any person or organization obtaining a copy
 * of the software and accompanying documentation covered by this license (the "Software") to use,
 * reproduce, display, distribute, execute, and transmit the Software, and to prepare derivative
 * works of the Software, and to permit third-parties to whom the Software is furnished to do so,
 * all subject to the following:
 * 
 * The copyright notices in the Software and this entire statement, including the above license
 * grant, this restriction and the following disclaimer, must be included in all copies of the Software,
 * in whole or in part, and all derivative works of the Software, unless such copies or derivative works
 * are solely in the form of machine-executable object code generated by a source language processor.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE
 * DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
module mqttd.messages;

import std.range;
import std.exception : enforce;
import std.traits : isIntegral;
import std.typecons : Nullable;
debug import std.stdio;

import mqttd.traits;

/**
* Exception thrown when package format is somehow malformed
*/
final class PacketFormatException : Exception
{
    this(string msg = null, Throwable next = null)
    {
        super(msg, next);
    }
}

enum ubyte MQTT_PROTOCOL_LEVEL_3_1_1 = 0x04;
enum string MQTT_PROTOCOL_NAME = "MQTT";

/**
 * MQTT Control Packet type
 * 
 * http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Table_2.1_-
 */
enum PacketType : ubyte
{
    /// Forbidden - Reserved
    RESERVED1   = 0,
    /// Client -> Server - Client request to connect to Server
    CONNECT     = 1,
    /// Server -> Client - Connect acknowledgment
    CONNACK     = 2,
    /// Publish message
    PUBLISH     = 3,
    /// Publish acknowledgment
    PUBACK      = 4,
    /// Publish received (assured delivery part 1)
    PUBREC      = 5,
    /// Publish release (assured delivery part 2)
    PUBREL      = 6,
    /// Publish complete (assured delivery part 3)
    PUBCOMP     = 7,
    /// Client -> Server - Client subscribe request
    SUBSCRIBE   = 8,
    /// Server -> Client - Subscribe acknowledgment
    SUBACK      = 9,
    /// Client -> Server - Unsubscribe request
    UNSUBSCRIBE = 10,
    /// Server -> Client - Unsubscribe acknowledgment
    UNSUBACK    = 11,
    /// Client -> Server - PING request
    PINGREQ     = 12,
    /// Server -> Client - PING response
    PINGRESP    = 13,
    /// Client -> Server - Client is disconnecting
    DISCONNECT  = 14,
    /// Forbidden - Reserved
    RESERVED2   = 15
}

/**
 * Indicates the level of assurance for delivery of an Application Message
 * http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Table_3.11_-
 */
enum QoSLevel : ubyte
{
    /// At most once delivery
    AtMostOnce = 0x0,
    /// At least once delivery
    AtLeastOnce = 0x1,
    /// Exactly once delivery
    ExactlyOnce = 0x2,
    /// Reserved – must not be used
    Reserved = 0x3
}

/// Connect Return code values - 0 = accepted, the rest means refused (6-255 are reserved)
enum ConnectReturnCode : ubyte
{
    /// Connection accepted
    ConnectionAccepted = 0x00,
    /// The Server does not support the level of the MQTT protocol requested by the Client
    ProtocolVersion    = 0x01,
    /// The Client identifier is correct UTF-8 but not allowed by the Server
    Identifier         = 0x02,
    /// The Network Connection has been made but the MQTT service is unavailable
    ServerUnavailable  = 0x03,
    /// The data in the user name or password is malformed
    UserNameOrPassword = 0x04,
    /// The Client is not authorized to connect
    NotAuthorized      = 0x05
}

/// Subscribe Return code values
enum SubscribeReturnCode : ubyte
{
    /// Success - Maximum QoS 0
    QoS0 = 0x00,
    /// Success - Maximum QoS 1
    QoS1 = 0x01,
    /// Success - Maximum QoS 2
    QoS2 = 0x02,
    /// Failure
    Failure = 0x80
}

/**
 * Each MQTT Control Packet contains a fixed header.
 * 
 * http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Figure_2.2_-
 */
struct FixedHeader
{
@safe pure @nogc nothrow:
    private ubyte _payload;

    /// Represented as a 4-bit unsigned value
    @property PacketType type() const
    {
        return cast(PacketType)(_payload >> 4);
    }

    /// ditto
    @property void type(in PacketType type)
    {
        _payload = cast(ubyte)((_payload & ~0xf0) | (type << 4));
    }

    /// Duplicate delivery of a PUBLISH Control Packet
    @property bool dup() const
    {
        return (_payload & 0x08) == 0x08;
    }

    /// ditto
    @property void dup(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x08) | (value ? 0x08 : 0x00));
    }
    
    /// Quality Of Service for a message
    @property QoSLevel qos() const
    {
        return cast(QoSLevel)((_payload >> 1) & 0x03);
    }

    /// ditto
    @property void qos(in QoSLevel value)
    {
        _payload = cast(ubyte)((_payload & ~0x06) | (value << 1));
    }
    
    /// PUBLISH Retain flag 
    @property bool retain() const
    {
        return (_payload & 0x01) == 0x01;
    }

    /// ditto
    @property void retain(in bool value)
    {
        _payload = cast(ubyte)(_payload & ~0x01) | (value ? 0x01 : 0x00);
    }

    /// flags to ubyte
    @property ubyte flags() const
    {
        return _payload;
    }

    @property void flags(in ubyte value)
    {
        _payload = value;
    }

    /**
     * The Remaining Length is the number of bytes remaining within the current packet, 
     * including data in the variable header and the payload. 
     * The Remaining Length does not include the bytes used to encode the Remaining Length.
     */
    uint length;

    alias flags this;

    this(PacketType type, bool dup, QoSLevel qos, bool retain, uint length = 0)
    {
        this.type = type;
        this.dup = dup;
        this.retain = retain;
        this.qos = qos;
        this.length = length;
    }

    this(T)(PacketType type, T flags, uint length = 0) if(isIntegral!T)
    {
        this.flags = cast(ubyte)(type << 4 | flags);
        this.type = type;
        this.length = length;
    }

    this(T)(T value) if(isIntegral!T)
    {
        this.flags = cast(ubyte)value;
    }
}

/**
 * The Connect Flags byte contains a number of parameters specifying the behavior of the MQTT connection.
 * It also indicates the presence or absence of fields in the payload.
 */
struct ConnectFlags
{
@safe pure @nogc nothrow:
    private ubyte _payload;
    
    /**
     * If the User Name Flag is set to 0, a user name MUST NOT be present in the payload.
     * If the User Name Flag is set to 1, a user name MUST be present in the payload.
     */
    @property bool userName() const
    {
        return (_payload & 0x80) == 0x80;
    }

    /// ditto
    @property void userName(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x80) | (value ? 0x80 : 0x00));
    }

    /**
     * If the Password Flag is set to 0, a password MUST NOT be present in the payload.
     * If the Password Flag is set to 1, a password MUST be present in the payload.
     * If the User Name Flag is set to 0, the Password Flag MUST be set to 0.
     */
    @property bool password() const
    {
        return (_payload & 0x40) == 0x40;
    }

    /// ditto
    @property void password(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x40) | (value ? 0x40 : 0x00));
    }

    /**
     * This bit specifies if the Will Message is to be Retained when it is published.
     * 
     * If the Will Flag is set to 0, then the Will Retain Flag MUST be set to 0.
     * If the Will Flag is set to 1:
     *      If Will Retain is set to 0, the Server MUST publish the Will Message as a non-retained message.
     *      If Will Retain is set to 1, the Server MUST publish the Will Message as a retained message
     */
    @property bool willRetain() const
    {
        return (_payload & 0x20) == 0x20;
    }

    /// ditto
    @property void willRetain(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x20) | (value ? 0x20 : 0x00));
    }

    /**
     * Specify the QoS level to be used when publishing the Will Message.
     * 
     * If the Will Flag is set to 0, then the Will QoS MUST be set to 0 (0x00).
     * If the Will Flag is set to 1, the value of Will QoS can be 0 (0x00), 1 (0x01), or 2 (0x02).
     * It MUST NOT be 3 (0x03)
     */
    @property QoSLevel willQoS() const
    {
        return cast(QoSLevel)((_payload >> 3) & 0x03);
    }

    /// ditto
    @property void willQoS(in QoSLevel value)
    {
        _payload = cast(ubyte)((_payload & ~0x18) | (value << 3));
    }

    /**
     * If the Will Flag is set to 1 this indicates that, if the Connect request is accepted, a Will Message MUST 
     * be stored on the Server and associated with the Network Connection. The Will Message MUST be published 
     * when the Network Connection is subsequently closed unless the Will Message has been deleted by the Server 
     * on receipt of a DISCONNECT Packet.
     * 
     * Situations in which the Will Message is published include, but are not limited to:
     *      An I/O error or network failure detected by the Server.
     *      The Client fails to communicate within the Keep Alive time.
     *      The Client closes the Network Connection without first sending a DISCONNECT Packet.
     *      The Server closes the Network Connection because of a protocol error.
     * 
     * If the Will Flag is set to 1, the Will QoS and Will Retain fields in the Connect Flags will be used by 
     * the Server, and the Will Topic and Will Message fields MUST be present in the payload.
     * 
     * The Will Message MUST be removed from the stored Session state in the Server once it has been published 
     * or the Server has received a DISCONNECT packet from the Client.
     * 
     * If the Will Flag is set to 0 the Will QoS and Will Retain fields in the Connect Flags MUST be set to zero 
     * and the Will Topic and Will Message fields MUST NOT be present in the payload.
     * 
     * If the Will Flag is set to 0, a Will Message MUST NOT be published when this Network Connection ends
     */
    @property bool will() const
    {
        return (_payload & 0x04) == 0x04;
    }

    /// ditto
    @property void will(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x04) | (value ? 0x04 : 0x00));
    }

    /**
     * This bit specifies the handling of the Session state. 
     * The Client and Server can store Session state to enable reliable messaging to continue across a sequence 
     * of Network Connections. This bit is used to control the lifetime of the Session state. 
     * 
     * If CleanSession is set to 0, the Server MUST resume communications with the Client based on state from 
     * the current Session (as identified by the Client identifier). 
     * If there is no Session associated with the Client identifier the Server MUST create a new Session. 
     * The Client and Server MUST store the Session after the Client and Server are disconnected.
     * After the disconnection of a Session that had CleanSession set to 0, the Server MUST store 
     * further QoS 1 and QoS 2 messages that match any subscriptions that the client had at the time of disconnection 
     * as part of the Session state.
     * It MAY also store QoS 0 messages that meet the same criteria.
     * 
     * If CleanSession is set to 1, the Client and Server MUST discard any previous Session and start a new one.
     * This Session lasts as long as the Network Connection. State data associated with this Session MUST NOT be reused
     * in any subsequent Session.
     * 
     * The Session state in the Client consists of:
     *      QoS 1 and QoS 2 messages which have been sent to the Server, but have not been completely acknowledged.
     *      QoS 2 messages which have been received from the Server, but have not been completely acknowledged. 
     * 
     * To ensure consistent state in the event of a failure, the Client should repeat its attempts to connect with 
     * CleanSession set to 1, until it connects successfully.
     * 
     * Typically, a Client will always connect using CleanSession set to 0 or CleanSession set to 1 and not swap 
     * between the two values. The choice will depend on the application. A Client using CleanSession set to 1 will 
     * not receive old Application Messages and has to subscribe afresh to any topics that it is interested in each 
     * time it connects. A Client using CleanSession set to 0 will receive all QoS 1 or QoS 2 messages that were 
     * published while it was disconnected. Hence, to ensure that you do not lose messages while disconnected, 
     * use QoS 1 or QoS 2 with CleanSession set to 0.
     * 
     * When a Client connects with CleanSession set to 0, it is requesting that the Server maintain its MQTT session 
     * state after it disconnects. Clients should only connect with CleanSession set to 0, if they intend to reconnect 
     * to the Server at some later point in time. When a Client has determined that it has no further use for 
     * the session it should do a final connect with CleanSession set to 1 and then disconnect.
     */
    @property bool cleanSession() const
    {
        return (_payload & 0x02) == 0x02;
    }

    /// ditto
    @property void cleanSession(in bool value)
    {
        _payload = cast(ubyte)((_payload & ~0x02) | (value ? 0x02 : 0x00));
    }

    @property ubyte flags() const
    {
        return _payload;
    }

    @property void flags(ubyte value) pure
    {
        _payload = value & ~0x01;
    }
    
    this(bool userName, bool password, bool willRetain, QoSLevel willQoS, bool will, bool cleanSession)
    {
        this.userName = userName;
        this.password = password;
        this.willRetain = willRetain;
        this.willQoS = willQoS;
        this.will = will;
        this.cleanSession = cleanSession;
    }
    
    this(T)(T value) if(isIntegral!T)
    {
        this.flags = cast(ubyte)(value & ~0x01);
    }
    
    alias flags this;

    unittest
    {
        import std.array;

        ConnectFlags flags;

        assert(flags == ConnectFlags(false, false, false, QoSLevel.AtMostOnce, false, false));
        assert(flags == 0);

        flags = 1; //reserved - no change
        assert(flags == ConnectFlags(false, false, false, QoSLevel.AtMostOnce, false, false));
        assert(flags == 0);

        flags = 2;
        assert(flags == ConnectFlags(false, false, false, QoSLevel.AtMostOnce, false, true));

        flags = 4;
        assert(flags == ConnectFlags(false, false, false, QoSLevel.AtMostOnce, true, false));

        flags = 24;
        assert(flags == ConnectFlags(false, false, false, QoSLevel.Reserved, false, false));

        flags = 32;
        assert(flags == ConnectFlags(false, false, true, QoSLevel.AtMostOnce, false, false));

        flags = 64;
        assert(flags == ConnectFlags(false, true, false, QoSLevel.AtMostOnce, false, false));

        flags = 128;
        assert(flags == ConnectFlags(true, false, false, QoSLevel.AtMostOnce, false, false));
    }
}

/// Connect Acknowledge Flags
struct ConnAckFlags
{
@safe pure @nogc nothrow:
    private ubyte _payload;

    /**
     * If the Server accepts a connection with CleanSession set to 1, the Server MUST set Session Present to 0 
     * in the CONNACK packet in addition to setting a zero return code in the CONNACK packet.
     *
     * If the Server accepts a connection with CleanSession set to 0, the value set in Session Present depends on 
     * whether the Server already has stored Session state for the supplied client ID. If the Server has stored 
     * Session state, it MUST set Session Present to 1 in the CONNACK packet. 
     * If the Server does not have stored Session state, it MUST set Session Present to 0 in the CONNACK packet.
     * This is in addition to setting a zero return code in the CONNACK packet.
     *
     * The Session Present flag enables a Client to establish whether the Client and Server have a consistent view 
     * about whether there is already stored Session state.
     *
     * Once the initial setup of a Session is complete, a Client with stored Session state will expect the Server 
     * to maintain its stored Session state. In the event that the value of Session Present received by the Client 
     * from the Server is not as expected, the Client can choose whether to proceed with the Session or to disconnect.
     * The Client can discard the Session state on both Client and Server by disconnecting, connecting with 
     * Clean Session set to 1 and then disconnecting again. 
     *
     * If a server sends a CONNACK packet containing a non-zero return code it MUST set Session Present to 0
     */
    @property bool sessionPresent() const
    {
        return (_payload & 0x01) == 0x01;
    }

    /// ditto
    @property void sessionPresent(in bool value)
    {
        _payload = cast(ubyte)(value ? 0x01 : 0x00);
    }

    @property ubyte flags() const
    {
        return _payload;
    }

    @property void flags(ubyte value) pure
    {
        _payload = cast(ubyte)(value & 0x01); //clean reserved bits
    }

    alias flags this;

    this(T)(T value) if(isIntegral!T)
    {
        this.flags = cast(ubyte)value;
    }
}

/// The payload of a SUBSCRIBE Packet
static struct Topic
{
    /**
     * Topic Filter indicating the Topic to which the Client wants to subscribe.
     * The Topic Filters in a SUBSCRIBE packet payload MUST be UTF-8 encoded strings.
     * A Server SHOULD support Topic filters that contain the wildcard characters.
     * If it chooses not to support topic filters that contain wildcard characters it MUST reject any Subscription request whose filter contains them
     */
    string filter;
    /// This gives the maximum QoS level at which the Server can send Application Messages to the Client.
    QoSLevel qos;
}

/**
 * After a Network Connection is established by a Client to a Server, 
 * the first Packet sent from the Client to the Server MUST be a CONNECT Packet.
 * 
 * A Client can only send the CONNECT Packet once over a Network Connection. 
 * The Server MUST process a second CONNECT Packet sent from a Client as a protocol violation and disconnect the Client.
 * 
 * The payload contains one or more encoded fields.
 * They specify a unique Client identifier for the Client, a Will topic, Will Message, User Name and Password.
 * All but the Client identifier are optional and their presence is determined based on flags in the variable header.
 */
struct Connect
{
    FixedHeader header = FixedHeader(0x10);

    /// The Protocol Name is a UTF-8 encoded string that represents the protocol name “MQTT”
    string protocolName = MQTT_PROTOCOL_NAME;

    /**
     * The 8 bit unsigned value that represents the revision level of the protocol used by the Client.
     * The value of the Protocol Level field for the version 3.1.1 of the protocol is 4 (0x04).
     */
    ubyte protocolLevel = MQTT_PROTOCOL_LEVEL_3_1_1;

    /**
     * The Connect Flags byte contains a number of parameters specifying the behavior of the MQTT connection.
     * It also indicates the presence or absence of fields in the payload.
     */
    ConnectFlags flags;

    /**
     * The Keep Alive is a time interval measured in seconds. Expressed as a 16-bit word, it is the maximum time 
     * interval that is permitted to elapse between the point at which the Client finishes transmitting one Control 
     * Packet and the point it starts sending the next. It is the responsibility of the Client to ensure that the 
     * interval between Control Packets being sent does not exceed the Keep Alive value. 
     * In the absence of sending any other Control Packets, the Client MUST send a PINGREQ Packet.
     * 
     * The Client can send PINGREQ at any time, irrespective of the Keep Alive value, and use the PINGRESP to determine 
     * that the network and the Server are working.
     * 
     * If the Keep Alive value is non-zero and the Server does not receive a Control Packet from the Client within 
     * one and a half times the Keep Alive time period, it MUST disconnect the Network Connection to the Client as if 
     * the network had failed.
     * 
     * If a Client does not receive a PINGRESP Packet within a reasonable amount of time after it has sent a PINGREQ, 
     * it SHOULD close the Network Connection to the Server.
     * 
     * A Keep Alive value of zero (0) has the effect of turning off the keep alive mechanism. 
     * This means that, in this case, the Server is not required to disconnect the Client on the grounds of inactivity.
     * Note that a Server is permitted to disconnect a Client that it determines to be inactive or non-responsive 
     * at any time, regardless of the Keep Alive value provided by that Client.
     * 
     * The actual value of the Keep Alive is application specific; typically this is a few minutes. 
     * The maximum value is 18 hours 12 minutes and 15 seconds. 
     */
    ushort keepAlive;

    /// Client Identifier
    string clientIdentifier;

    /// Will Topic
    string willTopic;

    /// Will Message
    string willMessage;

    /// User Name
    string userName;

    /// Password
    string password;
}

/// Responce to Connect request
struct ConnAck
{
    FixedHeader header = FixedHeader(PacketType.CONNACK, 0, 2);

    ConnAckFlags flags;

    ConnectReturnCode returnCode;
}

//TODO: PUBLISH
struct Publish
{
    FixedHeader header;
    ushort packetId; // if QoS > 0
}

/// A PUBACK Packet is the response to a PUBLISH Packet with QoS level 1.
struct PubAck
{
    FixedHeader header = FixedHeader(PacketType.PUBACK, 0, 2);

    /// This contains the Packet Identifier from the PUBLISH Packet that is being acknowledged. 
    ushort packetId;
}

/// A PUBREC Packet is the response to a PUBLISH Packet with QoS 2. It is the second packet of the QoS 2 protocol exchange.
struct PubRec
{
    FixedHeader header = FixedHeader(PacketType.PUBREC, 0, 2);
    /// This contains the Packet Identifier from the PUBLISH Packet that is being acknowledged. 
    ushort packetId;
}

/// A PUBREL Packet is the response to a PUBREC Packet. It is the third packet of the QoS 2 protocol exchange.
struct PubRel
{
    FixedHeader header = FixedHeader(PacketType.PUBREL, 0x02, 2);

    /// This contains the same Packet Identifier as the PUBREC Packet that is being acknowledged. 
    ushort packetId;
}

/// The PUBCOMP Packet is the response to a PUBREL Packet. It is the fourth and final packet of the QoS 2 protocol exchange.
struct PubComp
{
    FixedHeader header = FixedHeader(PacketType.PUBCOMP, 0, 2);

    /// This contains the same Packet Identifier as the PUBREC Packet that is being acknowledged. 
    ushort packetId;
}

/**
 * The SUBSCRIBE Packet is sent from the Client to the Server to create one or more Subscriptions.
 * Each Subscription registers a Client’s interest in one or more Topics.
 * The Server sends PUBLISH Packets to the Client in order to forward Application Messages that were published to Topics that match these Subscriptions.
 * The SUBSCRIBE Packet also specifies (for each Subscription) the maximum QoS with which the Server can send Application Messages to the Client.
 *
 * The payload of a SUBSCRIBE packet MUST contain at least one Topic Filter / QoS pair. A SUBSCRIBE packet with no payload is a protocol violation.
 */
struct Subscribe
{
    FixedHeader header = FixedHeader(PacketType.SUBSCRIBE, 0x02);
    
    /// This contains the Packet Identifier.
    ushort packetId;

    /// Topics to register to
    Topic[] topics;
}

/**
 * A SUBACK Packet is sent by the Server to the Client to confirm receipt and processing of a SUBSCRIBE Packet.
 * A SUBACK Packet contains a list of return codes, that specify the maximum QoS level that was granted in each 
 * Subscription that was requested by the SUBSCRIBE.
 */
struct SubAck
{
    FixedHeader header = FixedHeader(PacketType.SUBACK, 0);

    /// This contains the Packet Identifier from the SUBSCRIBE Packet that is being acknowledged.
    ushort packetId;
    /**
     * The payload contains a list of return codes. Each return code corresponds to a Topic Filter in the 
     * SUBSCRIBE Packet being acknowledged. 
     * The order of return codes in the SUBACK Packet MUST match the order of Topic Filters in the SUBSCRIBE Packet.
     */
    SubscribeReturnCode[] returnCodes;
}

/// An UNSUBSCRIBE Packet is sent by the Client to the Server, to unsubscribe from topics.
struct Unsubscribe
{
    FixedHeader header = FixedHeader(PacketType.UNSUBSCRIBE, 0x02);
    
    /// This contains the Packet Identifier.
    ushort packetId;
    
    /**
     * The list of Topic Filters that the Client wishes to unsubscribe from. The Topic Filters in an UNSUBSCRIBE packet MUST be UTF-8 encoded strings.
     * The Payload of an UNSUBSCRIBE packet MUST contain at least one Topic Filter. An UNSUBSCRIBE packet with no payload is a protocol violation.
     */
    string[] topics;
}

/// The UNSUBACK Packet is sent by the Server to the Client to confirm receipt of an UNSUBSCRIBE Packet.
struct UnsubAck
{
    FixedHeader header = FixedHeader(PacketType.UNSUBACK, 0, 2);

    /// This contains the same Packet Identifier as the UNSUBSCRIBE Packet that is being acknowledged. 
    ushort packetId;
}

/**
 * The PINGREQ Packet is sent from a Client to the Server. It can be used to:
 *
 * Indicate to the Server that the Client is alive in the absence of any other Control Packets being sent from the Client to the Server.
 * Request that the Server responds to confirm that it is alive.
 * Exercise the network to indicate that the Network Connection is active.
 *
 * This Packet is used in Keep Alive processing
 */
struct PingReq
{
    FixedHeader header = FixedHeader(PacketType.PINGREQ, 0, 0);
}

/**
 * A PINGRESP Packet is sent by the Server to the Client in response to a PINGREQ Packet. It indicates that the Server is alive.
 * This Packet is used in Keep Alive processing.
 */
struct PingResp
{
    FixedHeader header = FixedHeader(PacketType.PINGRESP, 0, 0);
}

/**
 * The DISCONNECT Packet is the final Control Packet sent from the Client to the Server. It indicates that the Client is disconnecting cleanly.
 *
 * After sending a DISCONNECT Packet the Client:
 *      MUST close the Network Connection.
 *      MUST NOT send any more Control Packets on that Network Connection.
 *
 * On receipt of DISCONNECT the Server:
 *      MUST discard any Will Message associated with the current connection without publishing it.
 *      SHOULD close the Network Connection if the Client has not already done so.
 */
struct Disconnect
{
    FixedHeader header = FixedHeader(PacketType.DISCONNECT, 0, 0);
}
