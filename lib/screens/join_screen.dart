// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'call_screen.dart';
import '../services/signalling.service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class JoinScreen extends StatefulWidget {
  final String selfCallerId;

  const JoinScreen({super.key, required this.selfCallerId});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  dynamic incomingSDPOffer;
  final remoteCallerIdTextEditingController = TextEditingController();

  List<String> connectedSockets = [];

  late Timer _timer;

  @override
  void dispose() {
    // Detiene el temporizador cuando el widget es eliminado
    _timer.cancel();
    super.dispose();
  }

  Future<void> fetchConnectedSockets() async {
    try {
      final response = await http.get(Uri.parse(
          "http://ec2-18-189-193-218.us-east-2.compute.amazonaws.com:5000/connectedClients"));
      if (response.statusCode == 200) {
        List<String> sockets = List<String>.from(json.decode(response.body));
        setState(() {
          connectedSockets = sockets;
        });
      } else {
        throw Exception('Failed to load connected clientes');
      }
    } catch (e) {
      print('No se puede conectar al servicio de clientes');
    }
  }

  @override
  void initState() {
    super.initState();

    // listen for incoming video call
    SignallingService.instance.socket!.on("newCall", (data) {
      if (mounted) {
        // set SDP Offer of incoming call
        setState(() => incomingSDPOffer = data);
      }
    });
    // Inicia el temporizador que ejecuta fetchConnectedSockets cada 10 segundos
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      fetchConnectedSockets();
    });

    // Ejecuta fetchConnectedSockets al iniciar el widget
    fetchConnectedSockets();

    // Escucha la llamada entrante
    SignallingService.instance.socket!.on("newCall", (data) {
      if (mounted) {
        setState(() => incomingSDPOffer = data);
      }
    });
  }

  // join Call
  _joinCall({
    required String callerId,
    required String calleeId,
    dynamic offer,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callerId: callerId,
          calleeId: calleeId,
          offer: offer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Meeting"),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: TextEditingController(
                        text: widget.selfCallerId,
                      ),
                      readOnly: true,
                      textAlign: TextAlign.center,
                      enableInteractiveSelection: false,
                      decoration: InputDecoration(
                        labelText: "Your Caller ID",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remoteCallerIdTextEditingController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "Remote Caller ID",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                      ),
                      child: const Text(
                        "Invite",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        _joinCall(
                          callerId: widget.selfCallerId,
                          calleeId: remoteCallerIdTextEditingController.text,
                        );
                      },
                    ),
                    const SizedBox(
                        height: 10), // Espacio para separar la lista del botón
                    Expanded(
                      // Para que la lista ocupe todo el espacio disponible
                      child: ListView.builder(
                        itemCount: connectedSockets.length,
                        itemBuilder: (BuildContext context, int index) {
                          return ListTile(
                            title: Text('Socket:  ${connectedSockets[index]}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (incomingSDPOffer != null)
              Positioned(
                child: ListTile(
                  title: Text(
                    "Incoming Call from ${incomingSDPOffer["callerId"]}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call_end),
                        color: Colors.redAccent,
                        onPressed: () {
                          setState(() => incomingSDPOffer = null);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call),
                        color: Colors.greenAccent,
                        onPressed: () {
                          _joinCall(
                            callerId: incomingSDPOffer["callerId"]!,
                            calleeId: widget.selfCallerId,
                            offer: incomingSDPOffer["sdpOffer"],
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
