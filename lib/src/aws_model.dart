part of aws_dart;

abstract class ApplicationResource {
  String region;
  String accountID;

  String get service;
  String get host;

  ApplicationResource();
  ApplicationResource.forAccount(this.region, this.accountID);

  AWSRequest newRequest(Map<String, dynamic> values) {
    var req = new AWSRequest()
      ..method = "POST"
      ..region = region
      ..service = service
      ..host = host;
    req.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8";

    req.requestBody = values.keys.map((k) {
      return "$k=${Uri.encodeQueryComponent(values[k])}";
    }).join("&");

    return req;
  }
}

class AWSConfiguration extends ConfigurationItem {
  String accessKey;
  String secretKey;
  String accountID;

  List<PlatformApplicationConfigurationItem> _sns;

  @optionalConfiguration
  void set sns(List<PlatformApplicationConfigurationItem> items) {
    _sns = items;
  }

  List<PlatformApplicationConfigurationItem> get sns {
    _sns.forEach((p) {
      p.accountID ??= accountID;
    });
    return _sns;
  }

  List<EmailConfigurationItem> _ses;

  @optionalConfiguration
  void set ses(List<EmailConfigurationItem> items) {
    _ses = items;
  }

  List<EmailConfigurationItem> get ses {
    _ses.forEach((p) {
      p.accountID ??= accountID;
    });
    return _ses;
  }
}
