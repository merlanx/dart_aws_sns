part of aws_dart;

class AWSRequest {
  String scheme = "https://";
  String method;
  String _host;
  String get host => _host;
  void set host(String host) {
    _host = host;
    headers["Host"] = host;
  }

  String accessKey;
  String secretKey;
  String service;
  String region;
  String path;
  Map<String, String> headers = {};

  DateTime _timestamp;
  void set timestamp(DateTime ts) {
    _timestamp = ts;
    headers["X-Amz-Date"] = amazonDateString;
  }

  Map<String, String> queryParameters;

  String requestBody = "";

  String get canonicalRequest {
    return "$method\n$canonicalURI\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$bodyHash";
  }

  String get canonicalURI {
    if (path == null || path == "/") {
      return "/";
    }
    return path.split("/").map((component) => Uri.encodeComponent(component)).join("/");
  }

  String get canonicalQueryString {
    if (queryParameters == null || queryParameters.isEmpty) {
      return "";
    }

    var keys = queryParameters.keys.toList();
    keys.sort();
    var items = keys.map((key) {
      return "${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(queryParameters[key])}";
    });

    return items.join("&") ?? "";
  }

  String get canonicalHeaders {
    var keys = headers.keys.toList();
    keys.sort();

    var items = keys.map((key) {
      return "${key.toLowerCase()}:${headers[key].trim()}";
    }).toList();

    return items.join("\n") +"\n";
  }

  String get signedHeaders {
    var keys = headers.keys.map((k) => k.toLowerCase()).toList();
    keys.sort();
    return keys.join(";");
  }

  String get credentialScope {
    var dateAsString = _timestamp.toIso8601String().split("T").first.replaceAll("-", "");

    return "$accessKey/$dateAsString/$region/$service/aws4_request";
  }

  String get bodyHash {
    return sha256.convert(UTF8.encode(requestBody)).toString();
  }

  String get amazonDateString {
    return _timestamp.toIso8601String()
        .replaceAll("-", "")
        .replaceAll(":", "")
        .split(".")
        .first + "Z";
  }

  String get stringToSign {
    var dateAsString = _timestamp.toIso8601String().split("T").first.replaceAll("-", "");
    var hashedCanonicalRequest = sha256.convert(UTF8.encode(canonicalRequest)).toString();

    return "AWS4-HMAC-SHA256\n"
        + amazonDateString + "\n"
        + "$dateAsString/$region/$service/aws4_request\n"
        + "$hashedCanonicalRequest";
  }

  String get signature {
    var signingKey = calculateSigningKey(secretKey, _timestamp, region, service);

    return calculateSignature(signingKey, stringToSign);
  }
  String get authorizationHeader {
    return "AWS4-HMAC-SHA256 Credential=$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature";
  }

  Future<AWSResponse> execute() async {
    timestamp = new DateTime.now().toUtc();
    if (method == "POST") {
      var h = headers;
      h["Authorization"] = authorizationHeader;

      var result = await http.post("$scheme$host/${path ?? ""}", headers: h, body: requestBody);
      return new AWSResponse.fromHTTPResponse(result);
    }

    return null;
  }

  static String calculateSignature(List<int> key, String inputString) {
    var hmac = new Hmac(sha256, key);
    return hmac.convert(UTF8.encode(inputString)).toString();
  }

  static List<int> calculateSigningKey(String secretKey, DateTime date, String region, String service) {
    var dateAsString = date.toIso8601String().split("T").first.replaceAll("-", "");

    var initialKey = UTF8.encode("AWS4$secretKey");
    return [dateAsString, region, service, "aws4_request"]
        .map((str) => UTF8.encode(str))
        .fold(initialKey, (key, value) {
          var hmac = new Hmac(sha256, key);
          return hmac.convert(value).bytes;
        });
  }
}

class AWSResponse {
  AWSResponse();
  AWSResponse.fromHTTPResponse(http.Response resp) {
    statusCode = resp.statusCode;
    body = resp.body;

    if (statusCode < 300) {
      var doc = xml.parse(body);

      resultXMLElement = doc.rootElement
          .children
          .firstWhere((n) => n is xml.XmlElement && n.name.local != "ResponseMetadata",
            orElse: () => null);
    } else {
      error = _parseErrorMap(body);
    }
  }

  bool get wasSuccessful => statusCode < 300;
  int statusCode;
  String body;

  dynamic value;
  xml.XmlElement resultXMLElement;
  AWSException error;

  AWSException _parseErrorMap(String body) {
    var document = xml.parse(body);

    xml.XmlElement errorNode = document.rootElement
        .children
        .firstWhere((n) => n is xml.XmlElement && n.name.local == "Error",
          orElse: () => null);

    var code = errorNode?.children?.
      firstWhere((n) => n is xml.XmlElement && n.name.local == "Code",
        orElse: () => null)?.text;
    var message = errorNode?.children?.
    firstWhere((n) => n is xml.XmlElement && n.name.local == "Message",
        orElse: () => null)?.text;

    return new AWSException(statusCode, message, code);
  }
}