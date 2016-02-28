{ANSI FileFormat}


{Wrapper library for Dinect API POS (c)2012-2013 Dinect (mailto svz@dinect.com)
Библиотека-обертка для Dinect API POS

uses library:

xmlutil -  Borland Delphi Visual Component Library
IdHTTP, IdCookieManager - Indy
uLkJSON -  http://sourceforge.net/projects/lkjson/

note:
некоторые значения переменных читаются из ини файла
передача параметров функций - по ссылке (!) ( http://progs.biz/delphi/pascal/lessons/014.aspx )


Some variables are read from ini file
transfer function parameters - by reference (!) (http://www.delphibasics.co.uk/Article.asp?Name=Routines)


примеры вызова функций :
examples of calling functions:

a := Dinect.qTransact(
  sUrl,
  sDMToken,
  sDMAppToken,
  sAcceptLanguage,
  sUserAgent,
  StrToInt(sDebug),
  sOrder,
  True,          // проводить
  cCheckSumm,
  sCoupons.Count,
  sCoupons,
  sgPurUrl,
  cBonusAmmo,
  cBonusPay,   //bonus_payment - Количество потраченных на оплату покупки бонусов.
  iDiscount, //% скидки
  cSummDiscount, // сумма со скидкой
  cBonus, // сумма бонусов
  True, //   redim_auto: Boolean
  sItems ,
  StrToDateTime('01.01.1980')
  );


a := Dinect.qSearch(
  True,
  sCardIn,
  sUrl,
  sDMToken,
  sDMAppToken,
  sAcceptLanguage,
  sUserAgent,
  StrToInt(sDebug),
  cCheckSumm,
  cAmount,
  iBonus,
  sCard,
  iDiscount,
  iid,
  sFirst_name,
  sMiddle_name,
  iPurchases,
  iCouponsCount,
  sCoupons,
  cSummDiscount,
  sPurchasesUrl,
  sAvaUrl,
  sgItems,
  sLoyaltyType
  );





}



unit Dinect;
{$A+,B-,E-,R-}


interface

uses xmlutil,
  IdHTTP,
  SysUtils,
  Windows,
  IniFiles,
  DateUtils,
  ComObj,
  uLkJSON,
  Classes,
  Variants,
  IdCookieManager,
  Math,
  RegExpr
  ;

{

работа с токеном безопасности - регистрация токена кассы с помощью токена приложения

work with a security token  - registration POS-token through the application-token

}


function getTokens(
  const surl : string;
  const DMAppToken: string;
  const sDinCode: string;
  const sKassNote: string;
  const sKassComment: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  var   DMToken: string
):Integer;

{
транзакции.  не использовать режим с непустым ddate - это внутреняя функция

transaction. Do not use mode with a <ddate> - This is an internal function

}

function qTransact(
  const surl : string;
  const DMToken: string;
  const DMAppToken: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  const doc_id: string;
  const commit: Boolean;
  const sum_total:Currency;
  const couponscount:Integer;
  const coupons: TStringList;
  const purchases_url: string;
  const bonus_amount: Currency;
  const bonus_payment: Currency;
//  const loyalty_type: string ;

  var discount: Integer;
  var sum_with_discount:Currency;
  var sum_bonus: Currency  ;
  const redim_auto: Boolean;
  const items: string ;
  const ddate: TDateTime
): Integer;


{
поиск пользователя - поиск по номеру карты и номеру купона.
функция делает магический вызов qTransact(commit=false) - для определения размера скидки

Users search - search by card number and coupon number.
function makes magic call qTransact (commit = false) - to determine the size discounts

}

function qSearch(
  const trydiscount: Boolean;
  const sSearch: string;
  const surl : string;
  const DMToken: string;
  const DMAppToken: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  const checksumm: Currency;
  var amount: Currency;
  var bonus: int64;
  var card: string;
  var discount: Integer;
  var id: int64;
  var first_name: string;
  var middle_name: string;
  var purchases: Integer;
  var couponscount:Integer;
  var coupons: TStringList;
  var summdiscount: Currency;
  var purchasesurl: string ;
  var avaurl: string ;
  const items: string ;
  var loyalty_type: string ;
  var max_bonus_percent : Integer


): Integer;


{
Функция преобразования числа с плавающей точкой в формат числа Dinect API

Conversion function floating point to specific number format of Direct API

 132,4568 = 132.456
 132,4 = 132.400
 132 = 132.000

}
function FloatToApiStr( fValue:Currency  ; cCount:Integer  ):string ;



var
 sgProxyUrl,sgProxyPort,sgProxyUser,sgProxyPass,sgProxyAuth: string ;
 bgUseProxy, bgUseZlib : Boolean;

implementation

function isPhoneNumber(const S: string ):Boolean ;
var
  r: TRegExpr;

begin
  Result := False ;

  r := TRegExpr.Create ;
  r.Expression := '^((8|\+7)[\- ]?)?(\(?\d{3}\)?[\- ]?)?[\d\- ]{7,10}$' ;

  if r.Exec(S) then Result := True ;

  r.Free;


end;

function ReplaceStr(const S, Srch, Replace: string): string;
var
  I: Integer;
  Source: string;
begin
  Source := S;
  Result := '';
  repeat
    I := Pos(Srch, Source);
    if I > 0 then begin
      Result := Result + Copy(Source, 1, I - 1) + Replace;
      Source := Copy(Source, I + Length(Srch), MaxInt);
    end
    else Result := Result + Source;
  until I <= 0;
end;

function DelChars(const S: string; Chr: Char): string;
var
  I: Integer;
begin
  Result := S;
  for I := Length(Result) downto 1 do begin
    if Result[I] = Chr then Delete(Result, I, 1);
  end;
end;


function ExtractDomain(URL: string): string;
var
  I: Integer;
begin
  Result := URL;
  if Pos('://', URL) > 0 then
    Result := Copy(URL, Pos('://', Result) + 3, Length(URL));
  Delete(Result, Pos('/', Result), Length(URL))
end;

procedure LogFileOutput(const filepath, str: string);
var
  F: THandle;
  Tmp: AnsiString;
  //    Tmp: string;
begin
  if FileExists(filepath) then
    F := FileOpen(filepath, fmOpenWrite or fmShareDenyRead)
  else
    F := FileCreate(filepath, fmOpenWrite or fmOpenReadWrite or
      fmShareDenyWrite);
  try
    if F = INVALID_HANDLE_VALUE then
      Exit;
    FileSeek(F, 0, File_End);
    Tmp := str + #13#10;
    //    FileWrite( F, PAnsiChar( Tmp )^, Length( Tmp ) );
    FileWrite(F, PChar(Tmp)^, Length(Tmp));
  finally
    FileClose(F);
  end;
end;

procedure WriteLogError(AMessage: string = ''; eCode: integer = 0);
var sPath: string;
begin
  try
    GetDir(0, sPath);

    LogFileOutput( sPath+ '\ErrLog.txt', DateTimeToStr(Now) + ': ' + AMessage + ' code: '
      + inttostr(eCode));
  except
  end;
end;

procedure Init(const iDebug: Integer);
var
 iProxyAuth, iUseProxy, iUseZlib : Integer;
  DbIniFile: TIniFile;
  sPath: string[255];
begin
    GetDir(0, sPath);
    DbIniFile := TIniFile.Create(sPath + '\dinect.ini');

    iUseProxy:= DbIniFile.ReadInteger('main', 'UseProxy',0);
    if (iUseProxy>0 ) then
    begin

      sgProxyUrl  := DbIniFile.ReadString('main', 'ProxyUrl' , '');
      sgProxyPort := DbIniFile.ReadString('main', 'ProxyPort', '');

      iProxyAuth := DbIniFile.ReadInteger('main', 'ProxyAuth', 0);
      if iProxyAuth >0 then
      begin
        sgProxyAuth := '1';
        sgProxyUser := DbIniFile.ReadString('main', 'ProxyUser', '');
        sgProxyPass := DbIniFile.ReadString('main', 'ProxyPass', '');
      end
      else
        sgProxyAuth := '0';


      if Length(Trim( sgProxyUrl) ) >0 then
        bgUseProxy:= True
      else
        bgUseProxy:= False;
    end;

    iUseZlib := DbIniFile.ReadInteger('main', 'Usezlib',0);
    if iUseZlib >0  then
      bgUseZlib := True
    else
      bgUseZlib := False;


    if iDebug = 1 then
    begin

      WriteLogError('Dinect.init.out: UseProxy= '  + BoolToStr(bgUseProxy) );
      WriteLogError('Dinect.init.out: ProxyUrl= '  + sgProxyUrl  );
      WriteLogError('Dinect.init.out: ProxyPort= ' + sgProxyPort );

      WriteLogError('Dinect.init.out: ProxyAuth= ' + sgProxyAuth );
      WriteLogError('Dinect.init.out: ProxyUser= ' + sgProxyUser );
      WriteLogError('Dinect.init.out: ProxyPass= ' + sgProxyPass );
    end;

    DbIniFile.Free;

end;


function FloatToApiStr( fValue:Currency  ; cCount:Integer  ):string ;
{
 функция приводит число с плавающей точкой к виду nnnn.nnn , nnn.nn , nnn.000
 для передачи в API Dinect количества и цены номенклатуры в чеке

 132,4568 = 132.456
 132,4 = 132.400
 132 = 132.000
}
var
fTmp : Currency;
sFormat, sTmp : string;

  function MakeStr(C: Char; N: Integer): string;
  begin
    if N < 1 then Result := ''
    else
    begin
      if N > 255 then N := 255;
      Result:= StringOfChar(C,N);
    end;

  end;

begin

  fTmp := roundto( fValue, cCount*-1  );

  if cCount>0 then
    sFormat := '0.'+ MakeStr('0',cCount)
  else
    sFormat := '0.###' ;

  sTmp:= FormatFloat(sFormat,fTmp) ;
  Result:= ReplaceStr(sTmp, DecimalSeparator, '.' );

end;
//***************************************************************
//***************************************************************
//***************************************************************


function getTokens(
  const surl : string;
  const DMAppToken: string;
  const sDinCode: string;
  const sKassNote: string;
  const sKassComment: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  var   DMToken: string
):Integer;
var
  Http: TIdHTTP;
  Cookie: TIdCookieManager;
  js: TlkJSONobject;
  jb,jl: TlkJSONbase;
  sTmp: string;
  httpParam :TStringList;
  httpResponse :TStringStream;

begin
  js := TlkJSONobject.Create;
  http := TIdHTTP.Create;
  Cookie := TIdCookieManager.Create;
  http.CookieManager := Cookie;

  http.Request.Accept := 'application/json';
  http.Request.AcceptLanguage := sAcceptLanguage;
  http.Request.UserAgent := sUserAgent;

  Cookie.AddCookie('_dmapptoken=' + DMAppToken, ExtractDomain(sUrl));
//  Cookie.AddCookie('_dmtoken=' + DMToken, ExtractDomain(sUrl));

  httpParam.Add('sum_total= ');

    sTmp := http.Get(sUrl + 'users/tokens/');

    if iDebug = 1 then
    begin
      WriteLogError('Dinect.getTokens->API: ' + sUrl + 'users/tokens/');
      WriteLogError('API->Dinect.getTokens: http response card = ' + sTmp);
    end;

    sTmp := DelChars(sTmp, '[');
    sTmp := Trim(DelChars(sTmp, ']'));

    if (Length(sTmp) > 0) then
    begin
//      js := TlkJSON.ParseText(str) as TlkJSONobject;
    end;


end;

//***************************************************************
function qSearch(
  const trydiscount: Boolean;
  const sSearch: string;
  const surl : string;
  const DMToken: string;
  const DMAppToken: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  const checksumm: Currency;
  var amount: Currency;
  var bonus: int64;
  var card: string;
  var discount: Integer;
  var id: int64;
  var first_name: string;
  var middle_name: string;
  var purchases: Integer;
  var couponscount:Integer;
  var coupons: TStringList;
  var summdiscount: Currency;
  var purchasesurl: string ;
  var avaurl: string ;
  const items: string ;
  var loyalty_type: string ;
  var max_bonus_percent: Integer

): Integer;

var
  sXML, sTmp, S: string;
  saTmp: AnsiString;
  flag: boolean;
  js: TlkJSONobject;
  jb,jl: TlkJSONbase;

//  sUrl,
  sDin, sPicture, str, sUserUrl,sPurUrl, sCouponsUrl, sAvaUrl, sDopInfo: string;
  cBonus, cBonusPay, cBonusAmmo, cSummTotal, cSummDiscount, cAmount:Currency;
  sLoyalty_type, sAmount, sCard, sFirst_name, sMiddle_name: string;
  iTmp, a, i, iCouponsCount, iPurchases, iDiscount, iid, iMax_purchase_percentage :Integer;
  iBonus: Int64 ;

  sCoupons :TStringList;
//  sItems :TStringList;
//  sHolder: string;
  Http: TIdHTTP;
  Cookie: TIdCookieManager;
  MS: TMemoryStream;
  ii: Integer;
  httpParam2: TStringList;
  httpResponse2: TStringStream;
  http2: TIdHTTP;
  Cookie2: TIdCookieManager;
//  CompressorZLib: TIdCompressorZLib;
begin

//Init(iDebug, sUrl);
if iDebug = 1 then
begin
   WriteLogError('................................');
   WriteLogError('Dinect.qSearch.BEGIN');
   WriteLogError('................................');
end;


amount        := 0  ;
bonus         := 0  ;
card          := '' ;
discount      := 0  ;
id            := 0  ;
first_name    := '' ;
middle_name   := '' ;
purchases     := 0  ;
couponscount  := 0  ;
purchasesurl  := '' ;
avaurl        := '' ;
iMax_purchase_percentage :=0;

Init(0);


Result := 1;

  js := TlkJSONobject.Create;
  http := TIdHTTP.Create;
  Cookie := TIdCookieManager.Create;
  sCoupons:= TStringList.Create;
  http.CookieManager := Cookie;
//  CompressorZLib :=  TIdCompressorZLib.Create;

  if bgUseProxy then
  begin
    http.ProxyParams.ProxyServer:= sgProxyUrl;
    http.ProxyParams.ProxyPort:= StrToInt( sgProxyPort );

    if ( sgProxyAuth='1' ) then
    begin
      HTTP.ProxyParams.BasicAuthentication := true;
      Http.ProxyParams.ProxyUsername := sgProxyUser;
      Http.ProxyParams.ProxyPassword := sgProxyPass;
    end;

  end;
  if bgUseZlib then
  begin
//    Http.Compressor := CompressorZLib;
  end;


  http.Request.Accept := 'application/json';
  http.Request.AcceptLanguage := sAcceptLanguage;
  http.Request.UserAgent := sUserAgent;



  Cookie.AddCookie('_dmapptoken=' + DMAppToken, ExtractDomain(sUrl));
  Cookie.AddCookie('_dmtoken=' + DMToken, ExtractDomain(sUrl));

  try
    // ищем сначала по номеру карты, если не находим- то по номеру купона
    // по номеру телефона поиск пока не имеет смысла
    // 25 символьные коды: отрезаются до 13  фиксленом
    // телефон набирается оператором с 3 символами впереди- потом режутся фиксленом
    // нужно определить где телфон
    // определяем регэкспом http://habrahabr.ru/post/110731/
    //  ^((8|\+7)[\- ]?)?(\(?\d{3}\)?[\- ]?)?[\d\- ]{7,10}$

    WriteLogError('API->Dinect.qSearch: isPhoneNumber = ' + BoolToStr( isPhoneNumber(sSearch) ) + ' (-1=true, 0=false)'  )      ;

    if isPhoneNumber(sSearch) then
      begin
        str := http.Get(sUrl + 'users/?phone=' + sSearch);

//        http://pos-api.dinect.com/20130701/users/?phone=NNNNNNNNNNNN

      end
    else
      begin


      end;



    str := http.Get(sUrl + 'users/?card=' + sSearch);

    if iDebug = 1 then
    begin
      WriteLogError('Dinect.qSearch->API: ' + sUrl + 'users/?card=' + sSearch);
      WriteLogError('API->Dinect.qSearch: http response card = ' + str);
    end;

    str := DelChars(str, '[');
    str := Trim(DelChars(str, ']'));

    if (Length(str) > 0) then
    begin

      js := TlkJSON.ParseText(str) as TlkJSONobject;

      sAvaUrl := vartostr(js.Field['photo_urls'].Field['100x125'].Value);
      sCouponsUrl := js.getString('coupons_url');
      sPurUrl := js.getString('purchases_url');
      sUserUrl := js.getString('url');
      sLoyalty_type  :=  js.getString('loyalty_url') ;

      sAmount := js.getString('amount');
      sAmount := ReplaceStr(sAmount, '.', DecimalSeparator );
      cAmount := StrToFloatdef( sAmount,0 );

      iBonus    := Round( js.getDouble('bonus') );

      if iDebug = 1 then
      begin
        WriteLogError('API->Dinect.qSearch: bonus  = ' + FloatToStr( js.getDouble('bonus') ) );
      end;

      sCard   := js.getString('card');
      iid     := js.getInt('id') ;

      iDiscount     := js.getInt('discount');

//      sFirst_name   := js.getString('first_name');
      sFirst_name  := vartostr(js.Field['first_name'].Value) ;
//      sMiddle_name  := js.getString('middle_name');
      sMiddle_name  := vartostr(js.Field['middle_name'].Value) ;
      iPurchases    := js.getInt('purchases');
      //      sDin := Inttostr(js.getInt('id'));



      Result := 0;
    end
    else
    begin
      // не нашли по карте, ищем купон - 71510072
      str := http.Get(sUrl + 'users/?coupon=' + sSearch);

      if iDebug = 1 then
      begin

        WriteLogError('Dinect.qSearch->API: ' + sUrl + 'users/?coupon=' + sSearch);
        WriteLogError('API->Dinect.qSearch: http response coupon = ' + str);
      end;

      str := DelChars(str, '[');
      str := Trim(DelChars(str, ']'));

      if (Length(str) > 0) then
      begin

        js := TlkJSON.ParseText(str) as TlkJSONobject;

        sAvaUrl     := vartostr(js.Field['photo_urls'].Field['100x125'].Value);
        sCouponsUrl := js.getString('coupons_url');
        sPurUrl     := js.getString('purchases_url');
        sUserUrl    := js.getString('url');
        sLoyalty_type  :=  js.getString('loyalty_url') ;

        sAmount     := js.getString('amount');
        sAmount     := ReplaceStr(sAmount, '.', DecimalSeparator );
        cAmount     := StrToFloatdef( sAmount,0 );

        iBonus    := Round( js.getDouble('bonus') );

        if iDebug = 1 then
        begin
          WriteLogError('API->Dinect.qSearch: bonus  = ' + FloatToStr( js.getDouble('bonus') ) );
        end;

        sCard       := js.getString('card');
        iid         := js.getInt('id') ;
        iDiscount   := js.getInt('discount');
        sFirst_name := js.getString('first_name');
        sMiddle_name:= js.getString('middle_name');
        iPurchases  := js.getInt('purchases');

//        js.Free;
        Result := 0;
      end
      else
        Result := 1; // не нашли
    end;


    // читаем тип системы лояльности
    if Result = 0 then
    begin
      str := http.Get(sLoyalty_type);


      if iDebug = 1 then
      begin
        WriteLogError('Dinect.qSearch.parseJSON->API: sLoyalty_url = ' + sLoyalty_type);
        WriteLogError('API->Dinect.qSearch.parseJSON: Response = ' + str);
      end;

      if (Length(str) > 0) then
      begin

        js := TlkJSON.ParseText(str) as TlkJSONobject;
        loyalty_type :=js.getString('type') ;
        //  читаем максимально возможную оплату бонусами
        iMax_purchase_percentage := js.getInt('max_purchase_percentage') ;

      end;

      if iDebug = 1 then
      begin
        WriteLogError('Dinect.qSearch.parseJSON: sLoyalty_type=' + loyalty_type);
        WriteLogError('Dinect.qSearch.parseJSON: SumBonus=' + IntToStr( iBonus ) );
        WriteLogError('Dinect.qSearch.parseJSON: iMax_purchase_percentage=' + IntToStr( iMax_purchase_percentage ) );


      end;

      if sLoyalty_type = 'bonus' then
        cBonusPay := iBonus;






    end;


    // считаем купоны
    if Result = 0 then
    begin
      str := http.Get(sCouponsUrl+'?status=ACTIVE');


      if iDebug = 1 then
      begin

        WriteLogError('Dinect.qSearch.parseJSON->API: sCouponsUrl = ' + sCouponsUrl+ '?status=ACTIVE');    //
        WriteLogError('API->Dinect.qSearch.parseJSON: Response = ' + str);    //
      end;

      if (Length(str) > 0) then
      begin

        js := TlkJSON.ParseText(str) as TlkJSONobject;
        iCouponsCount :=js.getint('total') ;

        jb:=js.Field['results'];

        for I := 0 to Pred(jb.Count) do
        begin
          jl := jb.Child[i];
          if Assigned(jl) then
          begin
              sTmp := VarToStr( jl.Field['status'].Value );
              if sTmp='ACTIVE' then
              begin
                  sTmp := VarToStr( jl.Field['id'].Value );
                  sTmp := sTmp+ '='+VarToStr( jl.Field['offer_name'].Value )+';';
                  sCoupons.Add(sTmp)

              end;
          end;
        end;
        if iDebug = 1 then
          WriteLogError('Dinect.qSearch.parseJSON: Coupons List=' + sCoupons.Text);

      end;
    end
    else
        iCouponsCount:=0 ;

    if iDebug = 1 then
      WriteLogError('Dinect.qSearch: checksumm=' +  FloatToStr (checksumm) );

    // проводим транзакцию с commit=false
    if (checksumm >0 ) then
      cSummTotal := checksumm
    else
      //на кошечках, равных 1000р чтобы узнать %% скидки
//      cSummTotal := 1000;
      cSummTotal := 0;


    a:=0;    // !!!!!
    if Result = 0 then
    begin
// вызваем с iCouponsCount =0 чтобы посчитать макс скидку
      if trydiscount then
      begin
        if iDebug = 1 then
        begin
          WriteLogError('Dinect.qSearch: in param items= ' + items);
          WriteLogError('Dinect.qSearch: call dinect.qTransact');

        end;


        a:= qTransact( surl, DMToken,DMAppToken,sAcceptLanguage,sUserAgent,
          iDebug,'',
          false, // не проводим
          cSummTotal,0,sCoupons, // игнорируется
          sPurUrl,cBonusAmmo,cBonusPay, iDiscount,  //% скидки
          cSummDiscount, // сумма скидки
          cBonus, // сумма бонусов
          True, //   redim_auto: Boolean
          items,
          StrToDateTime('01.01.1980')
          );

        if iDebug = 1 then
          WriteLogError('Dinect.qSearch: end of call dinect.qTransact');

      end;


    end;


    if a<1 then
    begin
        // возвращаем
        amount        := cAmount        ;
        bonus         := iBonus         ;
        card          := sCard          ;
        discount      := iDiscount      ;
        id            := iid            ;
        first_name    := sFirst_name    ;
        middle_name   := sMiddle_name   ;
        purchases     := iPurchases     ;
        couponscount  := iCouponsCount  ;
        coupons       := sCoupons       ;
        summdiscount  := cSummDiscount  ;
        purchasesurl  := sPurUrl        ;
        avaurl        := sAvaUrl        ;
        max_bonus_percent := iMax_purchase_percentage;

        Result := 0;
    end
    else
    begin
        amount        := 0  ;
        bonus         := 0  ;
        card          := '' ;
        discount      := 0  ;
        id            := 0  ;
        first_name    := '' ;
        middle_name   := '' ;
        purchases     := 0  ;
        couponscount  := 0  ;
        purchasesurl  := '' ;
        avaurl        := '' ;

        Result := 1;
    end;

if iDebug = 1 then
begin
   WriteLogError('................................');
   WriteLogError('Dinect.qSearch.END');
   WriteLogError('................................');
end;

  except
    on e: EOleException do
    begin
      Result := 1;
      if (e.ErrorCode = -2147467259) then
      begin
        WriteLogError(e.Message + ' num 1. Error code: ', e.ErrorCode);
      end
      else
        WriteLogError(e.Message + ' num 2. Error code: ', e.ErrorCode);
    end;
    on e2: Exception do
      WriteLogError(e2.Message + ' num 3.');
  end;
  js.Free;

end;

//*************************************************************************
function qTransact(
  const surl : string;
  const DMToken: string;
  const DMAppToken: string;
  const sAcceptLanguage: string;
  const sUserAgent: string;
  const iDebug: Integer;
  const doc_id: string;
  const commit: Boolean;
  const sum_total:Currency;
  const couponscount:Integer;
  const coupons: TStringList;
  const purchases_url: string;
  const bonus_amount: Currency;
  const bonus_payment: Currency;
//  const loyalty_type: string ;

  var discount: Integer;
  var sum_with_discount:Currency;
  var sum_bonus: Currency;
  const redim_auto: Boolean;
  const items: string ;
  const ddate: TDateTime
): Integer;

var
//  sUrl,
  sXML, sTmp, S: string;
  saTmp: AnsiString;
  js: TlkJSONobject;
  jb,jl: TlkJSONbase;

  sCouponscount, sDoc_id, sCommit,sSum_total, sSum_with_discount: string;

  sDate, sCoupons, sDiscounts, sBonus_amount, sBonus_payment: string;
  Http: TIdHTTP;
  Cookie: TIdCookieManager;
  MS: TMemoryStream;
  i: Integer;
  httpParam :TStringList;
  httpResponse :TStringStream;
//  CompressorZLib: TIdCompressorZLib;

begin
  if iDebug = 1 then
  begin

    WriteLogError('++++++++++++++++++++++++++++');
    WriteLogError('Dinect.qTransact: Begin');
    WriteLogError('++++++++++++++++++++++++++++');

  end;

  Result:=1;

  http := TIdHTTP.Create;
  Cookie := TIdCookieManager.Create;
  http.CookieManager := Cookie;
//  CompressorZLib :=  TIdCompressorZLib.Create;

  http.Request.Accept := 'application/json';
  http.Request.AcceptLanguage := sAcceptLanguage;
  http.Request.UserAgent := sUserAgent;

  if bgUseProxy then
  begin
    http.ProxyParams.ProxyServer:= sgProxyUrl;
    http.ProxyParams.ProxyPort:= StrToInt( sgProxyPort );

    if ( sgProxyAuth='1' ) then
    begin
      HTTP.ProxyParams.BasicAuthentication := true;
      Http.ProxyParams.ProxyUsername := sgProxyUser;
      Http.ProxyParams.ProxyPassword := sgProxyPass;
    end;

  end;
  if bgUseZlib then
  begin
//    Http.Compressor := CompressorZLib;
  end;


  Cookie.AddCookie('_dmapptoken=' + DMAppToken, ExtractDomain(sUrl));
  Cookie.AddCookie('_dmtoken=' + DMToken, ExtractDomain(sUrl));


      httpParam := TStringList.Create;
      httpResponse := TStringStream.Create('');

      if (Length(Trim(doc_id))>0 ) then
      begin
        sDoc_id := Trim(doc_id); // не доверять
        httpParam.Add('doc_id='+sDoc_id);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: doc_id = ' + sDoc_id );
      end;


      if ( sum_total > 0 ) then
      begin
        sSum_total:= FloatToStr(sum_total);
        sSum_total := ReplaceStr(sSum_total, DecimalSeparator, '.');
        httpParam.Add('sum_total='+sSum_total);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sSum_total = ' + sSum_total );
      end;

      if (sum_with_discount > 0 ) then
      begin
        sSum_with_discount:= FloatToStr(sum_with_discount);
        sSum_with_discount:= ReplaceStr(sSum_with_discount, DecimalSeparator, '.');
        httpParam.Add('sum_with_discount='+sSum_with_discount);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sSum_with_discount = ' + sSum_with_discount );
      end;

      if (bonus_amount > 0 ) then
      begin
        sBonus_amount:= FloatToStr(bonus_amount);
        sBonus_amount:= ReplaceStr(sBonus_amount, DecimalSeparator, '.');
        httpParam.Add('bonus_amount='+sBonus_amount);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sBonus_amount = ' + sBonus_amount );
      end;

//      if ( loyalty_type = 'bonus' ) then
//      begin
//        sBonus_amount:= FloatToStr(bonus_amount);
//        sBonus_amount:= ReplaceStr(sBonus_amount, DecimalSeparator, '.');
//        httpParam.Add('bonus_amount='+sBonus_amount);
//        if iDebug = 1 then
//          WriteLogError('Dinect.qTransact->API: sBonus_amount = ' + sBonus_amount );
//      end;


      if (bonus_payment > 0 ) then
      begin
        sBonus_payment:= FloatToStr(bonus_payment);
        sBonus_payment:= ReplaceStr(sBonus_payment, DecimalSeparator, '.');
        httpParam.Add('bonus_payment='+sBonus_payment);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sBonus_payment = ' + sBonus_payment );
      end;

      if (couponscount>0) and (coupons.Count>0) then
      begin
        sCoupons:='';
        for i:= 0 to couponscount-1 do
          begin
            sCoupons := sCoupons + coupons.Strings[i]+',';
          end;
        httpParam.Add('coupons=' + sCoupons);
        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sCoupons = ' + sCoupons );
      end;

      if ( Length( items ) >0 ) then
      begin
//        for i:= 0 to items.Count-1 do
//          begin
//            sItems := sItems + items.Strings[i];
//            if (i < (items.Count-1) ) then
//              sItems := sItems + ',';
//
//          end;
         httpParam.Add('items=' + items);

        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: items = ' + items );

      end;


      if commit = True then
        httpParam.Add('commit=true')
      else
        httpParam.Add('commit=false');


      if redim_auto = True then
      begin
            if couponscount>0 then
              httpParam.Add('redeem_auto=true')
            else
              httpParam.Add('redeem_auto=false');

      end
      else
            httpParam.Add('redeem_auto=false');

      if ( ddate > StrToDateTime('01.01.1980') ) then
      begin
//   Дата/время проведения покупки в формате %Y-%m-%d %H:%M:%S, для проведения покупки задним числом
//          sDate := DateTimeToStr( ddate ) ;
        sDate := FormatDateTime('yyyy-mm-dd hh:nn:ss',ddate ) ;
        httpParam.Add('date='+sDate);

        if iDebug = 1 then
          WriteLogError('Dinect.qTransact->API: sDate = ' + sDate );
      end;


      //    httpParam.Add('items='); //Список номенклатурных позиций (
    if iDebug = 1 then
    begin
      WriteLogError('Dinect.qTransact->API: http URL = ' + purchases_url );
      WriteLogError('Dinect.qTransact->API: http param transact = ' + httpParam.Text );
    end;

  try

    try
        if (Length(Trim(purchases_url)) >0) then
            Http.Post( purchases_url, httpParam, httpResponse );

        sTmp := httpResponse.DataString;

    except
        sTmp := httpResponse.DataString;
//        if Http.ResponseCode = 400 then
          Result := 1;
    end;

    sTmp := DelChars(sTmp, '[');
    sTmp := Trim(DelChars(sTmp, ']'));

    if iDebug = 1 then
    begin
        WriteLogError('API->Dinect.qTransact: http httpResponse transact = ' + sTmp );
        WriteLogError('API->Dinect.qTransact: http httpResponse code = ' + IntToStr(Http.ResponseCode) );
    end;

    if (Http.ResponseCode =201) or (Http.ResponseCode =200)   then
      Result:=0;

    // 400= нет купонов
    if Http.ResponseCode = 400 then
      Result := 1;

    if (Length(sTmp) > 0) then
    begin

      js := TlkJSON.ParseText(sTmp) as TlkJSONobject;

      discount:=js.getInt('discount');

      sTmp := js.getString('sum_discount');
      sTmp := ReplaceStr(sTmp, '.', DecimalSeparator );

      sum_with_discount:= StrToCurr(sTmp) ;
      sum_bonus:= js.getInt('sum_bonus');

    end
    else
    begin
      discount:=0;
      sum_with_discount:=0;
      sum_bonus := 0;
    end;


  except
    on e: EOleException do
    begin
      if (e.ErrorCode = -2147467259) then
      begin
        WriteLogError(e.Message + ' num 1. Error code: ', e.ErrorCode);
      end
      else
        WriteLogError(e.Message + ' num 2. Error code: ', e.ErrorCode);
    end;
    on e2: Exception do
      WriteLogError(e2.Message + ' num 3.');
  end;


 if iDebug = 1 then
 begin
  WriteLogError('Dinect.qTransact: result = ' + IntToStr( result ) );
  WriteLogError('Dinect.qTransact: End');
  WriteLogError('.');
 end;

end;


function test(): string;
begin

  test := 'testtring';

end;

end.

