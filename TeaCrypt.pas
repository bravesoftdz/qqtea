unit TeaCrypt;

interface

uses
  SysUtils;

function h2ns(wHost: Word): Word;
function h2nl(dwHost: Cardinal): Cardinal;
function n2hs(wNet: Word): Word;
function n2hl(dwNet: Cardinal): Cardinal;
function rand_r(var seed: Cardinal): Integer;
//TEA���ܡ�pPlainָ������ܵ����ġ�uPlainLen���ĳ��ȡ�pKey��Կ16�ֽڡ�
//pOutָ�����������������pOutLen�������������ָʾ�������������(���ĳ���)��
//����ֵ��-1����ʧ�ܣ�0���������̫С������ֵ������ܳɹ���
function TeaEncrypt(const pPlain: Pointer; uPlainLen: Cardinal;
  const pKey: Pointer; pOut: Pointer; var pOutLen: Cardinal): Integer; overload;
function TeaEncrypt(const pPlain: Pointer; uPlainLen: Cardinal;
  const sKey: AnsiString): AnsiString; overload;
function TeaEncrypt(const sPlain: AnsiString; const sKey: AnsiString): AnsiString; overload;
function TeaEncrypt(const sPlain: string; const sKey: AnsiString; bConvUTF8: Boolean): AnsiString; overload;
//TEA���ܡ�pCipherָ����������ġ�uCipherLen���ĳ��ȡ�pKey��Կ16�ֽڡ�
//pOutָ�����������������pOutLen�������������ָʾ�������������(���ĳ���)��
//����ֵ��-1����ʧ�ܣ�0���������̫С������ֵ������ܳɹ���
function TeaDecrypt(const pCipher: Pointer; uCipherLen: Cardinal;
  const pKey: Pointer; pOut: Pointer; var pOutLen: Cardinal): Integer; overload;
function TeaDecrypt(const pCipher: Pointer; uCipherLen: Cardinal;
  const sKey: AnsiString): AnsiString; overload;
function TeaDecrypt(const sCipher: AnsiString; const sKey: AnsiString;
  bDecodeUTF8: Boolean = False): AnsiString; overload;

implementation

type
  CardinalArray  = array[0..15] of Cardinal;
  PCardinalArray = ^CardinalArray;

  TEACTX = record
    buf: array[0..7] of Byte;
    bufPre: array[0..7] of Byte;
    pKey: PAnsiChar;
    pCrypt: PAnsiChar;
    pCryptPre: PAnsiChar;
    uRandSeed: Cardinal;
  end;

const
  KArrByteOrder: array[0..1] of Byte = ($55, $AA);

function h2ns(wHost: Word): Word;
begin
  if PWORD(@KArrByteOrder[0])^ = $55AA then
    Result := wHost
  else
    Result := Word((wHost shr 8) or (wHost shl 8));
end;

function h2nl(dwHost: Cardinal): Cardinal;
begin
  if PWORD(@KArrByteOrder[0])^ = $55AA then
    Result := dwHost
  else
    Result := (dwHost shr 24) or (dwHost shl 24) or ((dwHost shr 8) and $FF00) or ((dwHost shl 8) and $FF0000);
end;

function n2hs(wNet: Word): Word;
begin
  Result := h2ns(wNet);
end;

function n2hl(dwNet: Cardinal): Cardinal;
begin
  Result := h2nl(dwNet);
end;

procedure memset(dst: Pointer; val: Integer; count: Integer);
begin
  while count > 0 do
  begin
    Dec(count);
    (PAnsiChar(dst))^ := AnsiChar(val);
    dst := Pointer(PAnsiChar(dst)+ 1);
  end;
end;

function rand_r(var seed: Cardinal): Integer;
var
  next, ret: Cardinal;
begin
  next := seed;
  next := next * 1103515245;
  next := next + 12345;
  ret := (next div 65535) mod 2048;
  next := next * 1103515245;
  next := next + 12345;
  ret := ret shl 10;
  ret := ret xor ((next div 65535) mod 1024);
  next := next * 1103515245;
  next := next + 12345;
  ret := ret shl 10;
  ret := ret xor ((next div 65535) mod 1024);
  seed := next;
  Result := Integer(ret);
end;

function Random(var ctx: TEACTX): Cardinal;
begin
  Result := rand_r(ctx.uRandSeed);
end;

//TEA���ܡ�v����8�ֽڡ�k��Կ16�ֽڡ�w�������8�ֽڡ�
procedure encipher(const v: PCardinalArray; const k: PCardinalArray; w: PCardinalArray);
var
  y, z, a, b, c, d, n, sum, delta: Cardinal;
begin
  y := h2nl(v[0]);
  z := h2nl(v[1]);
  a := h2nl(k[0]);
  b := h2nl(k[1]);
  c := h2nl(k[2]);
  d := h2nl(k[3]);
  n := 16; //do encrypt 16 (0x10) times
  sum := 0;
  delta := $9E3779B9; //0x9E3779B9 - 0x100000000 = -0x61C88647
  while n > 0 do
  begin
    Dec(n);
    sum := sum + delta;
    y := y + (((z shl 4) + a) xor (z + sum) xor ((z shr 5) + b));
		z := z + (((y shl 4) + c) xor (y + sum) xor ((y shr 5) + d));
  end;
  w[0] := n2hl(y);
	w[1] := n2hl(z);
end;

//TEA���ܡ�v����8�ֽڡ�k��Կ16�ֽڡ�w�������8�ֽڡ�
procedure decipher(const v: PCardinalArray; const k: PCardinalArray; w: PCardinalArray);
var
  y, z, a, b, c, d, n, sum, delta: Cardinal;
begin
  y := h2nl(v[0]);
  z := h2nl(v[1]);
  a := h2nl(k[0]);
  b := h2nl(k[1]);
  c := h2nl(k[2]);
  d := h2nl(k[3]);
  n := 16; //do encrypt 16 (0x10) times
  sum := $E3779B90;
  delta := $9E3779B9; //why this ? must be related with n value
  //sum = delta<<5, in general sum = delta * n
  while n > 0 do
  begin
    Dec(n);
    z := z - (((y shl 4) + c) xor (y + sum) xor ((y shr 5) + d));
		y := y - (((z shl 4) + a) xor (z + sum) xor ((z shr 5) + b));
		sum := sum - delta;
  end;
  w[0] := n2hl(y);
	w[1] := n2hl(z);
end;

procedure TeaInitRandSeed(var ctx: TEACTX; uRandSeed: Cardinal);
begin
  ctx.uRandSeed := uRandSeed;
end;

function TeaEncNeedLen(nLen: Cardinal): Cardinal;
begin
  Result := 1 + ((8 - ((nLen + 10) and $07)) and $07) + 2 + nLen + 7;
end;

procedure EncryptEach8Bytes(var ctx: TEACTX);
begin
  PCardinalArray(@ctx.buf[0])[0] := PCardinalArray(@ctx.buf[0])[0] xor PCardinalArray(ctx.pCryptPre)[0];
	PCardinalArray(@ctx.buf[0])[1] := PCardinalArray(@ctx.buf[0])[1] xor PCardinalArray(ctx.pCryptPre)[1];
	encipher(PCardinalArray(@ctx.buf[0]), PCardinalArray(ctx.pKey), PCardinalArray(ctx.pCrypt));
  PCardinalArray(ctx.pCrypt)[0] := PCardinalArray(ctx.pCrypt)[0] xor PCardinalArray(@ctx.bufPre[0])[0];
  PCardinalArray(ctx.pCrypt)[1] := PCardinalArray(ctx.pCrypt)[1] xor PCardinalArray(@ctx.bufPre[0])[1];
  PCardinalArray(@ctx.bufPre[0])[0] := PCardinalArray(@ctx.buf[0])[0];
  PCardinalArray(@ctx.bufPre[0])[1] := PCardinalArray(@ctx.buf[0])[1];
  ctx.pCryptPre := ctx.pCrypt;
  ctx.pCrypt := ctx.pCrypt + 8;
end;

function TeaEncrypt(const pPlain: Pointer; uPlainLen: Cardinal;
  const pKey: Pointer; pOut: Pointer; var pOutLen: Cardinal): Integer;
var
  p: PByte;
  ctx: TEACTX;
  uOutLen: Cardinal;
  uPadLen, uPos: Byte;
begin
  Result := -1;
  if (pPlain = nil) or (uPlainLen = 0) or (pKey = nil) then Exit;
  //�������������������ͬ���ֽ���
	uPadLen := (8 - ((uPlainLen + 1 + 2 + 7) and $07)) and $07;
	//������ܺ�ĳ���
	uOutLen := 1 + uPadLen + 2 + uPlainLen + 7;
  if (pOut = nil) or (pOutLen < uOutLen) then
  begin
    pOutLen := uOutLen;
    Result := 0;
    Exit;
  end;
  ctx.uRandSeed := Cardinal(Trunc(Frac(Now) * 24*60*60*1000));
  //memset(@ctx.bufPre[0], 0, SizeOf(ctx.bufPre));
  FillChar(ctx.bufPre[0], SizeOf(ctx.bufPre), 0);
  ctx.pCrypt := PAnsiChar(pOut);
  ctx.pCryptPre := PAnsiChar(@ctx.bufPre[0]);
  ctx.pKey := PAnsiChar(pKey);
  ctx.buf[0] := Byte((Random(ctx) and $F8) or uPadLen);
  FillChar(ctx.buf[1], uPadLen, Byte(Random(ctx)));
  //memset(@ctx.buf[1], Byte(Random(ctx)), uPadLen);
  uPos := uPadLen + 1;
  for uPadLen := 0 to 1 do
  begin
    if uPos = 8 then
    begin
      EncryptEach8Bytes(ctx);
      uPos := 0;
    end;
    ctx.buf[uPos] := Byte(Random(ctx));
    Inc(uPos);
  end;
  p := PByte(pPlain);
  while uPlainLen > 0 do
  begin
    if uPos = 8 then
    begin
      EncryptEach8Bytes(ctx);
      uPos := 0;
    end;
    ctx.buf[uPos] := p^;
    Inc(p);
    Inc(uPos);
    Dec(uPlainLen);
  end;
  //ĩβ�����7�ֽ�0����ܣ��ڽ��ܹ��̵�ʱ����������ж�key�Ƿ���ȷ��
  //for uPadLen := 1 to 7 do
  //  ctx.buf[uPadLen] := $00;
  uPadLen := ctx.buf[0];
	PCardinalArray(@ctx.buf[0])[0] := 0;
	PCardinalArray(@ctx.buf[0])[1] := 0;
	ctx.buf[0] := uPadLen;
  EncryptEach8Bytes(ctx);
  pOutLen := uOutLen;
  Result := Integer(uOutLen);
end;

procedure DecryptEach8Bytes(var ctx: TEACTX);
begin
  PCardinalArray(@ctx.buf[0])[0] := PCardinalArray(ctx.pCrypt)[0] xor PCardinalArray(@ctx.bufPre[0])[0];
  PCardinalArray(@ctx.buf[0])[1] := PCardinalArray(ctx.pCrypt)[1] xor PCardinalArray(@ctx.bufPre[0])[1];
  decipher(PCardinalArray(@ctx.buf[0]), PCardinalArray(ctx.pKey), PCardinalArray(@ctx.bufPre[0]));
  PCardinalArray(@ctx.buf[0])[0] := PCardinalArray(@ctx.bufPre[0])[0] xor PCardinalArray(ctx.pCryptPre)[0];
  PCardinalArray(@ctx.buf[0])[1] := PCardinalArray(@ctx.bufPre[0])[1] xor PCardinalArray(ctx.pCryptPre)[1];
  ctx.pCryptPre := ctx.pCrypt;
  ctx.pCrypt := ctx.pCrypt + 8;
end;

function TeaDecrypt(const pCipher: Pointer; uCipherLen: Cardinal;
  const pKey: Pointer; pOut: Pointer; var pOutLen: Cardinal): Integer;
var
  ctx: TEACTX;
  uOutLen, u: Cardinal;
  uPos, uPadLen: Byte;
begin
  Result := -1;
  // �����ܵ����ݳ�������16�ֽڣ����ҳ���������8����������
  if (pCipher = nil) or (pKey = nil) or (uCipherLen < 16) or ((uCipherLen and $07) <> 0) then Exit;
  ctx.pKey := PAnsiChar(pKey);
  // �Ƚ���ͷ8�ֽڣ��Ա��ȡ��һ�ּ���ʱ���ĳ��ȡ�
  decipher(PCardinalArray(pCipher), PCardinalArray(pKey), PCardinalArray(@ctx.bufPre[0]));
  for u := 0 to 7 do
    ctx.buf[u] := ctx.bufPre[u];
  uPadLen := ctx.buf[0] and $07; //��һ�ּ���ʱ���ĳ���
  if uPadLen > 1 then
  begin
    for u := 2 to uPadLen-1 do
    begin
      if ctx.buf[1] <> ctx.buf[u] then
        Exit;
    end;
  end;
  uOutLen := uCipherLen - 1 - uPadLen - 2 - 7;
  if 1 + uPadLen + 2 + 7 > uCipherLen then Exit;
  if (pOut = nil) or (pOutLen < uOutLen) then
  begin
    pOutLen := uOutLen;
    Result := 0;
    Exit;
  end;
  ctx.pCryptPre := PAnsiChar(pCipher);
  ctx.pCrypt := PAnsiChar(pCipher) + 8;
  uPos := uPadLen + 1;
  for uPadLen := 0 to 1 do
  begin
    if uPos = 8 then
    begin
      DecryptEach8Bytes(ctx);
			uPos := 0;
    end;
    Inc(uPos);
  end;
  for u := 0 to uOutLen-1 do
  begin
    if uPos = 8 then
    begin
      DecryptEach8Bytes(ctx);
			uPos := 0;
    end;
    PByteArray(pOut)[u] := ctx.buf[uPos];
    Inc(uPos);
  end;
  ctx.buf[0] := 0;
  if (PCardinalArray(@ctx.buf[0])[0] <> 0) or (PCardinalArray(@ctx.buf[0])[1] <> 0) then
    Exit;
  //for uPadLen := 1 to 7 do
  //begin
  //  if ctx.buf[uPadLen] <> $00 then
  //    Exit;
  //end;
  pOutLen := uOutLen;
  Result := Integer(uOutLen);
end;

function TeaEncrypt(const pPlain: Pointer; uPlainLen: Cardinal; const sKey: AnsiString): AnsiString;
var
  uNeedLen: Cardinal;
begin
  Result := '';
  if (pPlain = nil) or (uPlainLen = 0) or (Length(sKey) < 16) then Exit;
  uNeedLen := TeaEncNeedLen(uPlainLen);
  SetLength(Result, uNeedLen);
  TeaEncrypt(pPlain, uPlainLen, PAnsiChar(sKey), @Result[1], uNeedLen);
end;

function TeaEncrypt(const sPlain: AnsiString; const sKey: AnsiString): AnsiString;
begin
  Result := TeaEncrypt(PAnsiChar(sPlain), Length(sPlain), sKey);
end;

function TeaEncrypt(const sPlain: string; const sKey: AnsiString; bConvUTF8: Boolean): AnsiString;
begin
  if bConvUTF8 then Result := TeaEncrypt(UTF8Encode(sPlain), sKey)
  else TeaEncrypt(sPlain, sKey);
end;

function TeaDecrypt(const pCipher: Pointer; uCipherLen: Cardinal; const sKey: AnsiString): AnsiString;
var
  uNeedLen: Cardinal;
  iRet: Integer;
begin
  Result := '';
  if (pCipher = nil) or (uCipherLen < 16) or ((uCipherLen and $07) <> 0) then Exit;
  uNeedLen := uCipherLen - 10;
  SetLength(Result, uNeedLen);
  iRet := TeaDecrypt(pCipher, uCipherLen, PAnsiChar(sKey), @Result[1], uNeedLen);
  if iRet > 0 then SetLength(Result, uNeedLen)
  else Result := '';
end;

function TeaDecrypt(const sCipher: AnsiString; const sKey: AnsiString; bDecodeUTF8: Boolean): AnsiString;
begin
  if bDecodeUTF8 then Result := UTF8Decode(TeaDecrypt(PAnsiChar(sCipher), Length(sCipher), sKey))
  else Result := TeaDecrypt(PAnsiChar(sCipher), Length(sCipher), sKey);
end;

end.
