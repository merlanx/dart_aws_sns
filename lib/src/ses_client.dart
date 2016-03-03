part of aws_dart;

class SESClient implements AWSClient {
  String accessKey;
  String secretKey;

  Future<bool> sendEmail(Email email, Stuff stuff) async {
    var req = new AWSRequest()
      ..method = "POST"
      ..region = stuff.region
      ..service = stuff.service
      ..accessKey = accessKey
      ..secretKey = secretKey
      ..host = stuff.host;
    req.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8";

    var emailMap = email.asMap();
    emailMap["Action"] = "SendEmail";
    req.requestBody = emailMap.keys.map((k) {
      return "$k=${Uri.encodeQueryComponent(emailMap[k])}";
    }).join("&");

    var response = await req.execute();
    if (response.statusCode != 200) {
      throw new ClientException(response.statusCode, response.body);
    }
    return true;
  }
}