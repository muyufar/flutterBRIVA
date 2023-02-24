import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: CreateBrivaPage(),
    );
  }
}

class CreateBrivaPage extends StatefulWidget {
  @override
  _CreateBrivaPageState createState() => _CreateBrivaPageState();
}

class _CreateBrivaPageState extends State<CreateBrivaPage> {
  final _formKey = GlobalKey<FormState>();
  late String _namaNasabah;
  int? _nominal;
  String clientSecret = '5e7Nrc8AZohER96A';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buat BRIVA Baru'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nama Nasabah',
                ),
                validator: (String? value) {
                  if (value != null && value.isEmpty) {
                    return 'Nama nasabah harus diisi';
                  }
                  return null;
                },
                onSaved: (value) {
                  _namaNasabah = value!;
                },
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nominal Pembayaran',
                ),
                keyboardType: TextInputType.number,
                validator: (String? value) {
                  if (value != null && value.isEmpty) {
                    return 'Nominal pembayaran harus diisi';
                  }
                  return null;
                },
                onSaved: (value) {
                  _nominal = int.parse(value!);
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('Buat VA BRI'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _createBriva();
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  String generateSignature(
    String path,
    String verb,
    String token,
    String timestamp,
    String body,
    String secret,
  ) {
    var tokenTrim = token.replaceAll(" ", "");
    var payload =
        "path=$path&verb=$verb&token=$token&timestamp=$timestamp&body=$body";
    var bytes = utf8.encode(Uri.encodeFull(payload));
    var secretBytes = utf8.encode(Uri.encodeFull(secret));
    var hmacSha256 = new Hmac(sha256, secretBytes);
    var digest = hmacSha256.convert(bytes);
    var base64String = base64.encode(digest.bytes);

    log("PAYLOAD: $payload");
    log("BYTE: $bytes");
    log("SECRET: $secretBytes");
    log("DIGEST: $digest");
    log("BASE64: $base64String");

    return base64String;
  }

  String brivaGenerateSignature(
    String path,
    String verb,
    String token,
    String timestamp,
    String payload,
    String secret,
  ) {
    String payloads =
        "path=$path&verb=$verb&token=$token&timestamp=$timestamp&body=$payload";
    List<int> signPayload =
        Hmac(sha256, utf8.encode(payloads)).convert(utf8.encode(secret)).bytes;
    log("PAYLOAD: $payloads");
    log("PAYLOAD_SIGN: $signPayload");

    return base64Encode(signPayload);
  }

  void _createBriva({http.Client? client}) async {
    client ??= http.Client();

    // ambil access token dari API Briva
    var response = await http.post(
        Uri.parse(
            'https://sandbox.partner.api.bri.co.id/oauth/client_credential/accesstoken?grant_type=client_credentials'),
        // headers: {
        //   'Content-Type': 'application/x-www-form-urlencoded',
        // },
        body: {
          // 'Content-Type': 'application/x-www-form-urlencoded',
          // 'grant_type': 'client_credentials',
          'client_id': '4DOmi9Ka9hLmvlPDiAhQTZcGjO7eEehW',
          'client_secret': clientSecret,
        });
    // }
    log("RESPONSE: ${response.body}");
    var accessToken = jsonDecode(response.body)['access_token'];
    log("ACCESS_TOKEN: $accessToken");

    var timestamp = DateTime.now().toUtc().toIso8601String();

    var signature = brivaGenerateSignature(
      "/v1/briva",
      "GET",
      "Bearer$accessToken",
      timestamp,
      "",
      clientSecret,
    );

    log("DATE: ${DateTime.now().toUtc().toIso8601String()}");
    // membuat BRIVA baru dengan request ke API Briva
    response = await http.post(
        (Uri.parse('https://sandbox.partner.api.bri.co.id/v1/briva')),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'BRI-Signature': signature,
          'BRI-Timestamp': timestamp,
        },
        body: json.encode({
          'institutionCode': 'J104408',
          'brivaNo': '77777',
          'custCode': '134679258',
          'nama': _namaNasabah,
          'amount': _nominal,
          'keterangan': 'Pembayaran dari aplikasi Flutter',
          'expiredDate':
              DateTime.now().add(Duration(days: 1)).toIso8601String(),
        }));

    log("SIGNATURE: $signature");
    log("DATE_ISO: ${DateTime.now().add(Duration(days: 1)).toIso8601String()}");
    log("STATUS_CODE: ${response.statusCode}");
    log("RESPONSE: ${response.body}");

    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);
      var brivaNo = responseBody['brivaNo'];
      var custCode = responseBody['custCode'];

      // tampilkan informasi BRIVA yang baru dibuat
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('BRIVA baru berhasil dibuat'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('BRIVA Number: $brivaNo'),
                  Text('Cust Code: $custCode'),
                  Text('Nama Nasabah: $_namaNasabah'),
                  Text('Nominal Pembayaran: Rp$_nominal,-'),
                ],
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      // tampilkan pesan error
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Gagal membuat BRIVA baru'),
            content: Text(response.body),
            actions: <Widget>[
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
