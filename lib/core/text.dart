/// Texto en minúsculas y sin tildes, para buscar sin preocuparse de acentos
/// («dragon» encuentra «Dragón»).
String foldText(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñçÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇ';
  const to = 'aaaaeeeeiiiioooouuuuncAAAAEEEEIIIIOOOOUUUUNC';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}
