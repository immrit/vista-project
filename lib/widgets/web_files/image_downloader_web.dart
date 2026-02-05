import 'dart:html' as html;

void downloadImageOnWeb(String imageUrl) {
  final anchor = html.AnchorElement(href: imageUrl)
    ..download = "chat_image.jpg"
    ..target = 'blank';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
