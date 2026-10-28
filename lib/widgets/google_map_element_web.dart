import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void configureGoogleMapElement(Object element, String source) {
  final iframe = element as JSObject;
  iframe
    ..setProperty('src'.toJS, source.toJS)
    ..setProperty('title'.toJS, 'Ubicación de Expresiones Eternas'.toJS)
    ..setProperty('loading'.toJS, 'lazy'.toJS)
    ..setProperty('allowFullscreen'.toJS, true.toJS)
    ..setProperty('referrerPolicy'.toJS, 'no-referrer-when-downgrade'.toJS);
  final style = iframe.getProperty<JSObject>('style'.toJS);
  style
    ..setProperty('border'.toJS, '0'.toJS)
    ..setProperty('width'.toJS, '100%'.toJS)
    ..setProperty('height'.toJS, '100%'.toJS);
}
