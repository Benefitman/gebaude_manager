import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class Begehung {
  final String beschreibung;
  List<Uint8List> bilder;
  String? inspectionTime;
  bool? isChecked;
  final TextEditingController titleController;
  final TextEditingController detailsController;

  Begehung({
    this.beschreibung = '',
    List<Uint8List>? bilder,
    this.inspectionTime,
    this.isChecked,
  })  : bilder = bilder ?? [],
        titleController = TextEditingController(),
        detailsController = TextEditingController();

  factory Begehung.fromJson(Map<String, dynamic> json) {
    List<Uint8List> bilderDecoded = [];
    if (json['bilder'] != null) {
      bilderDecoded = (json['bilder'] as List)
          .map((bild) => base64Decode(bild))
          .cast<Uint8List>()
          .toList();
    }

    var begehung = Begehung(
      beschreibung: json['beschreibung'],
      bilder: bilderDecoded,
      inspectionTime: json['inspectionTime'],
      isChecked: json['isChecked'] as bool?,
    );

    begehung.titleController.text = json['title'] ?? '';
    begehung.detailsController.text = json['details'] ?? '';

    return begehung;
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Begehung> _begehungen = [Begehung()];

  void _addBegehung() {
    setState(() {
      _begehungen.add(Begehung());
    });
  }

  Future<void> _pickImages(Begehung begehung) async {
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? selectedImages = await _picker.pickMultiImage();
    if (selectedImages != null) {
      List<Uint8List> imageBytes =
          await Future.wait(selectedImages.map((xFile) async {
        final byteData = await xFile.readAsBytes();
        return byteData;
      }));

      setState(() {
        begehung.bilder.addAll(imageBytes);
      });
      saveBegehungenToLocalStorage(_begehungen);
    }
  }

  void _captureCurrentTime(Begehung begehung) {
    setState(() {
      begehung.inspectionTime =
          DateFormat('dd.MM.yyyy  HH:mm').format(DateTime.now());
    });
    saveBegehungenToLocalStorage(_begehungen);
  }

  void saveBegehungenToLocalStorage(List<Begehung> begehungen) {
    List<Map<String, dynamic>> begehungenData = begehungen
        .map((begehung) => {
              "beschreibung": begehung.beschreibung,
              "bilder": begehung.bilder.map(base64Encode).toList(),
              "inspectionTime": begehung.inspectionTime,
              "isChecked": begehung.isChecked,
              "title": begehung.titleController.text,
              "details": begehung.detailsController.text,
            })
        .toList();
    String jsonData = jsonEncode(begehungenData);
    html.window.localStorage['begehungen'] = jsonData;
  }

  List<Begehung> loadBegehungenFromLocalStorage() {
    String? jsonData = html.window.localStorage['begehungen'];
    if (jsonData != null) {
      List<dynamic> begehungenData = jsonDecode(jsonData);
      return begehungenData.map<Begehung>((data) {
        List<Uint8List> bilder = (data['bilder'] as List<dynamic>)
            .map((bild) => base64Decode(bild as String))
            .toList();
        Begehung begehung = Begehung(
          beschreibung: data['beschreibung'],
          bilder: bilder,
          inspectionTime: data['inspectionTime'],
          isChecked: data['isChecked'],
        );
        begehung.titleController.text = data['title'];
        begehung.detailsController.text = data['details'];
        return begehung;
      }).toList();
    }
    return [];
  }

  Future<void> createPdfFromLocalStorage() async {
    final String? jsonData = html.window.localStorage['begehungen'];
    if (jsonData == null) {
      print('Keine Daten zum Erstellen des PDFs gefunden.');
      return;
    }

    List<dynamic> begehungenData = jsonDecode(jsonData);

    final pdf = pw.Document();

    for (var data in begehungenData) {
      final begehung = Begehung.fromJson(data);

      String pruefstatus =
          begehung.isChecked == true ? 'GEPRÜFT' : 'NICHT GEPRÜFT';

      pdf.addPage(pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(level: 1, text: begehung.titleController.text),
            pw.Paragraph(text: "Status: $pruefstatus"),
            pw.Paragraph(text: "Details: ${begehung.detailsController.text}"),
            pw.Paragraph(
                text: "Zeitpunkt der Begehung: ${begehung.inspectionTime}"),
            ...begehung.bilder
                .map((bild) => pw.Image(pw.MemoryImage(bild)))
                .toList(),
          ];
        },
      ));
    }

    Uint8List pdfInBytes = await pdf.save();

    final blob = html.Blob([pdfInBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'begehung.pdf')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void createPdfAndDownload({
    required String title,
    required String details,
    required String dateTime,
    List<Uint8List>? images,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 1, text: title),
          pw.Paragraph(text: "Details: $details"),
          pw.Paragraph(text: "Zeitpunkt der Begehung: $dateTime"),
          if (images != null)
            for (var image in images) pw.Image(pw.MemoryImage(image)),
        ],
      ),
    );

    Uint8List pdfInBytes = await pdf.save();

    final blob = html.Blob([pdfInBytes], 'application/pdf');

    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'begehung.pdf')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<Uint8List> generatePdf(List<Begehung> begehungen) async {
    final pdf = pw.Document();

    for (var begehung in begehungen) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text(begehung.titleController.text),
            pw.Column(
                children: begehung.bilder
                    .map((bild) => pw.Image(pw.MemoryImage(bild)))
                    .toList()),
          ];
        },
      ));
    }

    return pdf.save();
  }

  void downloadFile(Uint8List fileContent, String fileName) {
    final blob = html.Blob([fileContent], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void resetAllEntries() {
    setState(() {
      _begehungen = [Begehung()];
    });
    saveBegehungenToLocalStorage(
        _begehungen);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Begehung durchführen'),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: _begehungen.map((begehung) {
              int index = _begehungen.indexOf(begehung) + 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Begehung $index',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ListTile(
                    title: Text('Zeitpunkt der Begehung'),
                    trailing: IconButton(
                      icon: Icon(Icons.access_time),
                      color: Colors.black,
                      iconSize: 40.0,
                      onPressed: () => _captureCurrentTime(begehung),
                    ),
                    subtitle: begehung.inspectionTime != null
                        ? Text('Erfasst: ${begehung.inspectionTime}')
                        : null,
                  ),
                  RadioListTile<bool>(
                    title: Text('geprüft'),
                    value: true,
                    groupValue: begehung.isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        begehung.isChecked = value;
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    title: Text('nicht geprüft'),
                    value: false,
                    groupValue: begehung.isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        begehung.isChecked = value;
                      });
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: begehung.titleController,
                      decoration: InputDecoration(
                        labelText: 'Überschrift',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      onEditingComplete: () {
                        saveBegehungenToLocalStorage(_begehungen);
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: TextField(
                      controller: begehung.detailsController,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      onEditingComplete: () {
                        saveBegehungenToLocalStorage(_begehungen);
                      },
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  ),
                  Wrap(
                    children: begehung.bilder
                        .map((bild) => Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Image.memory(
                                bild,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ))
                        .toList(),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImages(begehung),
                    child: Text('Fotos hochladen'),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                  Divider(),
                ],
              );
            }).toList()
              ..add(
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _addBegehung,
                      child: Text('Weitere Begehung hinzufügen'),
                    ),
                  ],
                ),
              ),
          ),
        ),
        floatingActionButton: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              bottom: 50,
              right: 10,
              child: FloatingActionButton(
                onPressed: () {
                  createPdfFromLocalStorage();
                },
                child: Icon(Icons.picture_as_pdf),
                tooltip: 'PDF erstellen',
              ),
            ),
            Positioned(
              bottom: 50,
              left: 35,
              child: FloatingActionButton(
                onPressed: () {
                  resetAllEntries();
                },
                child: Icon(Icons.delete_forever),
                tooltip: 'Alles zurücksetzen',
                backgroundColor:
                    Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
