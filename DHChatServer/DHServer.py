# coding=utf-8
from twisted.web import server, resource
from twisted.internet import protocol, reactor, endpoints
from struct import *
import logging
import md5
import json
import uuid
import time
from time import localtime, strftime

#server config
SOCKET_SERVER_PORT = 8888
HTTP_SERVER_PORT = 9090
gClientSocketHash = {}
gClientIDHash = {}
gClientInfoList = {}

'''
{
	"encypted" : true,
	"type": "",
	"message": "",
	"to": "client_id",
	"from": "client_id"
}


"encypted" : true | false
"type" : 
{
	"send_key": "send public key",
	"get_key": "get public key",
	"send_message": "send message",
	"send_name": "send name",
	"exit": ""
}
'''


class ServerProtocol(protocol.Protocol):
	def connectionMade(self):   		
		client_id = uuid.uuid1().hex;
		print( self.transport.client[0] + " server was accepted with client_id " + client_id);
		gClientSocketHash[self] = {
			"client_id": client_id,
			"name": client_id,
			"key": ""
		}		
		tempObject = json.loads(json.dumps(gClientSocketHash[self]))
		gClientIDHash[client_id] = tempObject
		gClientIDHash[client_id]["socket"] = self
		gClientInfoList[client_id] = gClientSocketHash[self]
            
            
	def connectionLost(self, reason):
		client_id = gClientSocketHash[self]["client_id"]
		del(gClientIDHash[client_id])
		del(gClientInfoList[client_id])
		del(gClientSocketHash[self])
		print( self.transport.client[0] + " server was disconnnected. Error " + str(reason))

	def dataReceived(self, data):
		try:
			#Convert receive data to json
			jsonData = json.loads(data);
			encypted = False
			type = ""
			message = ""
			toUser = ""
			fromUser = ""
		
			client_id = gClientSocketHash[self]["client_id"]
			if "encypted" in jsonData:
				encypted = jsonData["encypted"]
			if "type" in jsonData:
				type = jsonData["type"]
			if "message" in jsonData:
				message = jsonData["message"]
			if "to" in jsonData:
				toUser = jsonData["to"]
			if "from" in jsonData:
				fromUser = jsonData["from"]

			#send message
			sendMessae = {
				"encypted" : encypted,
				"type": type,
				"message": "",
				"from": toUser,
				"to": fromUser
				
			}
				
			#User send public key
			if type == "send_key":
				gClientSocketHash[self]["key"] = message
			
			#Get partner public key
			elif type == "get_key":
				if toUser in gClientIDHash:
					partnerKey = gClientIDHash[toUser]["key"]					
					sendMessae["message"] = partnerKey
					self.transport.write(json.dumps(sendMessae))
			#User send nickname
			elif type == "send_name":
				gClientSocketHash[self]["name"] = message
			#User send name
			elif type == "send_message":
				if toUser in gClientIDHash:
					partnerSocket = gClientIDHash[toUser]["socket"]					
					sendMessae["message"] = message
					partnerSocket.transport.write(json.dumps(sendMessae))
				else:
					sendMessae["type"] = "exit"
					self.transport.write(json.dumps(sendMessae))					
			#update client info for gClientIDHash
			tempObject = json.loads(json.dumps(gClientSocketHash[self]))
			gClientIDHash[client_id] = tempObject
			gClientIDHash[client_id]["socket"] = self
			gClientInfoList[client_id] = gClientSocketHash[self]
			
		
		except Exception, ex:		
			print "Error while parse json message ", ex
        

class ServerFactory(protocol.Factory):
	def buildProtocol(self, addr):
		return ServerProtocol()


class DHHttpProtocol(resource.Resource):    
	isLeaf = True
	def render_GET(self, request):
		if (request.uri == "/get_client_list"):
			return json.dumps(gClientInfoList)
		return json.dumps({})

siteHttp = server.Site(DHHttpProtocol())			
reactor.listenTCP(SOCKET_SERVER_PORT, ServerFactory())
reactor.listenTCP(HTTP_SERVER_PORT, siteHttp)
reactor.run()
