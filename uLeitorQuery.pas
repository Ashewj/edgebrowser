unit uLeitorQuery;

{
  Lê diretamente o conteúdo de TFDQuery.SQL.Text a partir
  dos recursos binários DFM vinculados à aplicação em
  execução. Não cria o formulário, não conecta ao
  banco de dados e não acessa nenhum arquivo
  DFM no disco.

  Exemplo:

  var vSql := TLeitorQuery
    .New
    .FromForm('frmOrders') // 'TfrmOrders' também é aceito
    .FromQuery('qryOrders')
    .SQLText;
}

interface

uses
  System.SysUtils,
  Winapi.Windows,
  System.Classes,
  System.StrUtils,
  FireDAC.Comp.Client;

type
  ELeitorQuery = class(Exception);

  ILeitorQuery = interface
    ['{B5073BF3-D577-4E82-B3C9-D0F8EE1EB9B5}']
    function Form(const AFormName: string):   ILeitorQuery;
    function Query(const AQueryName: string): ILeitorQuery;

    function SQLText:                         string;
    function TrySQLText(out AText: string):   Boolean;
  end;

  TLeitorQuery = class(TInterfacedObject, ILeitorQuery)
  private
    FFormName: string;
    FQueryName: string;

    function _ReadCore(out AText, AError: string): Boolean;
  public
    constructor Create;
    destructor Destroy;                       override;
    class function New:                       ILeitorQuery;

    function Form(const AFormName: string):   ILeitorQuery;
    function Query(const AQueryName: string): ILeitorQuery;

    function SQLText:                         string;
    function TrySQLText(out AText: string):   Boolean;
  end;

  TPesquisaApi = class
  private
    FFormName:       string;
    FQueryName:      string;
    FFoundForm:      Boolean;
    FFoundQuery:     Boolean;
    FWrongQueryType: Boolean;
    FMalformedSql:   Boolean;
    FSuccess:        Boolean;
    FSqlText:        string;

    function InspectResource(const AModule: THandle; const AResourceName: string): Boolean;
  public
    constructor Create(const AFormName, AQueryName: string);
    function ScanModule(const AModule: THandle): Boolean;
    function Execute(out AText, AError: string): Boolean;
  end;

implementation

function UnqualifiedName(const AName: string): string;
var
  LDot: Integer;
begin
  Result := Trim(AName);
  LDot := LastDelimiter('.', Result);
  if LDot > 0 then
    Delete(Result, 1, LDot);
end;

function FormNameMatches(const ARequested, AResourceName, ARootName,
  ARootClass: string): Boolean;
var
  LRequested: string;
begin
  LRequested := UnqualifiedName(ARequested);
  Result :=
    SameText(LRequested, UnqualifiedName(AResourceName)) or
    SameText(LRequested, ARootName) or
    SameText(LRequested, ARootClass) or
    ((Length(ARootClass) > 1) and (UpCase(ARootClass[1]) = 'T') and
      SameText(LRequested, Copy(ARootClass, 2, MaxInt))) or
    ((Length(LRequested) > 1) and (UpCase(LRequested[1]) = 'T') and
      SameText(Copy(LRequested, 2, MaxInt), ARootName));
end;

function TryParseComponentHeader(const ALine: string; out AName,
  AClassName: string): Boolean;
const
  CPrefixes: array[0..2] of string = ('object ', 'inherited ', 'inline ');
var
  I: Integer;
  LColon: Integer;
  LRest: string;
  LSpace: Integer;
begin
  Result := False;
  AName := '';
  AClassName := '';
  LRest := TrimLeft(ALine);

  for I := Low(CPrefixes) to High(CPrefixes) do
    if StartsText(CPrefixes[I], LRest) then
    begin
      Delete(LRest, 1, Length(CPrefixes[I]));
      LColon := Pos(':', LRest);
      if LColon = 0 then
        Exit;

      AName := Trim(Copy(LRest, 1, LColon - 1));
      AClassName := Trim(Copy(LRest, LColon + 1, MaxInt));
      LSpace := Pos(' ', AClassName);
      if LSpace > 0 then
        SetLength(AClassName, LSpace - 1);

      Result := (AName <> '') and (AClassName <> '');
      Exit;
    end;
end;

function LeadingSpaceCount(const ALine: string): Integer;
begin
  Result := 0;
  while (Result < Length(ALine)) and CharInSet(ALine[Result + 1], [' ', #9]) do
    Inc(Result);
end;

function IsFDQueryClass(const AClassName: string): Boolean;
var
  LClass: TPersistentClass;
  LName: string;
begin
  LName := UnqualifiedName(AClassName);
  if SameText(LName, TFDQuery.ClassName) then
    Exit(True);

  LClass := GetClass(LName);
  Result := Assigned(LClass) and LClass.InheritsFrom(TFDQuery);
end;

function TrySplitProperty(const ALine: string; out AName,
  AValue: string): Boolean;
var
  LEquals: Integer;
begin
  LEquals := Pos('=', ALine);
  Result := LEquals > 0;
  if not Result then
    Exit;

  AName := Trim(Copy(ALine, 1, LEquals - 1));
  AValue := Trim(Copy(ALine, LEquals + 1, MaxInt));
end;

function FindUnquotedChar(const AText: string; const AChar: Char): Integer;
var
  I: Integer;
  LInString: Boolean;
begin
  Result := 0;
  LInString := False;
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '''' then
    begin
      if LInString and (I < Length(AText)) and (AText[I + 1] = '''') then
        Inc(I)
      else
        LInString := not LInString;
    end
    else if not LInString and (AText[I] = AChar) then
      Exit(I);
    Inc(I);
  end;
end;

function RemoveTrailingConcat(var AText: string): Boolean;
var
  I: Integer;
begin
  I := Length(AText);
  while (I > 0) and CharInSet(AText[I], [' ', #9]) do
    Dec(I);
  Result := (I > 0) and (AText[I] = '+');
  if Result then
  begin
    Delete(AText, I, MaxInt);
    AText := TrimRight(AText);
  end;
end;

function TryDecodeDfmString(const AExpression: string;
  out AValue: string): Boolean;
var
  I: Integer;
  LCode: Integer;
  LDigits: string;
  LClosed: Boolean;
begin
  Result := False;
  AValue := '';
  I := 1;

  while I <= Length(AExpression) do
  begin
    if CharInSet(AExpression[I], [' ', #9, #13, #10, '+']) then
    begin
      Inc(I);
      Continue;
    end;

    if AExpression[I] = '''' then
    begin
      Inc(I);
      LClosed := False;
      while I <= Length(AExpression) do
      begin
        if AExpression[I] <> '''' then
        begin
          AValue := AValue + AExpression[I];
          Inc(I);
          Continue;
        end;

        if (I < Length(AExpression)) and (AExpression[I + 1] = '''') then
        begin
          AValue := AValue + '''';
          Inc(I, 2);
        end
        else
        begin
          Inc(I);
          LClosed := True;
          Break;
        end;
      end;
      if not LClosed then
        Exit;
      Continue;
    end;

    if AExpression[I] = '#' then
    begin
      Inc(I);
      if (I <= Length(AExpression)) and (AExpression[I] = '$') then
      begin
        Inc(I);
        LDigits := '';
        while (I <= Length(AExpression)) and
          CharInSet(AExpression[I], ['0'..'9', 'A'..'F', 'a'..'f']) do
        begin
          LDigits := LDigits + AExpression[I];
          Inc(I);
        end;
        if (LDigits = '') or not TryStrToInt('$' + LDigits, LCode) then
          Exit;
      end
      else
      begin
        LDigits := '';
        while (I <= Length(AExpression)) and
          CharInSet(AExpression[I], ['0'..'9']) do
        begin
          LDigits := LDigits + AExpression[I];
          Inc(I);
        end;
        if (LDigits = '') or not TryStrToInt(LDigits, LCode) then
          Exit;
      end;

      if (LCode < 0) or (LCode > Ord(High(Char))) then
        Exit;
      AValue := AValue + Char(LCode);
      Continue;
    end;

    Exit;
  end;

  Result := True;
end;

function TryReadStringList(const ALines: TStrings; const APropertyIndex: Integer;
  const APropertyValue: string; out AText: string): Boolean;
var
  I: Integer;
  LOpen: Integer;
  LClose: Integer;
  LPiece: string;
  LExpression: string;
  LDecoded: string;
  LContinues: Boolean;
  LDone: Boolean;
  LSqlLines: TStringList;
begin
  Result := False;
  AText := '';
  LOpen := FindUnquotedChar(APropertyValue, '(');
  if LOpen = 0 then
    Exit;

  LSqlLines := TStringList.Create;
  try
    I := APropertyIndex;
    LPiece := Copy(APropertyValue, LOpen + 1, MaxInt);
    LExpression := '';
    LDone := False;

    while not LDone do
    begin
      LClose := FindUnquotedChar(LPiece, ')');
      if LClose > 0 then
      begin
        Delete(LPiece, LClose, MaxInt);
        LDone := True;
      end;

      LPiece := Trim(LPiece);
      if LPiece <> '' then
      begin
        LContinues := RemoveTrailingConcat(LPiece);
        LExpression := LExpression + LPiece;
        if not LContinues then
        begin
          if not TryDecodeDfmString(LExpression, LDecoded) then
            Exit;
          LSqlLines.Add(LDecoded);
          LExpression := '';
        end;
      end;

      if LDone then
        Break;

      Inc(I);
      if I >= ALines.Count then
        Exit;
      LPiece := ALines[I];
    end;

    if LExpression <> '' then
    begin
      if not TryDecodeDfmString(LExpression, LDecoded) then
        Exit;
      LSqlLines.Add(LDecoded);
    end;

    AText := LSqlLines.Text;
    Result := True;
  finally
    LSqlLines.Free;
  end;
end;

function TryExtractSql(const ALines: TStrings; const AQueryName: string;
  out AText: string; out AFoundQuery, AWrongType,
  AMalformed: Boolean): Boolean;
var
  I: Integer;
  J: Integer;
  LHeaderIndent: Integer;
  LName: string;
  LClassName: string;
  LPropertyName: string;
  LPropertyValue: string;
begin
  Result := False;
  AText := '';
  AFoundQuery := False;
  AWrongType := False;
  AMalformed := False;

  for I := 0 to ALines.Count - 1 do
  begin
    if not TryParseComponentHeader(ALines[I], LName, LClassName) or
      not SameText(LName, AQueryName) then
      Continue;

    AFoundQuery := True;
    if not IsFDQueryClass(LClassName) then
    begin
      AWrongType := True;
      Continue;
    end;

    LHeaderIndent := LeadingSpaceCount(ALines[I]);
    J := I + 1;
    while J < ALines.Count do
    begin
      if LeadingSpaceCount(ALines[J]) <= LHeaderIndent then
        Break;

      if (LeadingSpaceCount(ALines[J]) = LHeaderIndent + 2) and
        TrySplitProperty(Trim(ALines[J]), LPropertyName, LPropertyValue) then
      begin
        if SameText(LPropertyName, 'SQL.Strings') or
          SameText(LPropertyName, 'SQL') then
        begin
          if not TryReadStringList(ALines, J, LPropertyValue, AText) then
          begin
            AMalformed := True;
            Exit;
          end;
          Exit(True);
        end;

        if SameText(LPropertyName, 'SQL.Text') then
        begin
          if not TryDecodeDfmString(LPropertyValue, AText) then
          begin
            AMalformed := True;
            Exit;
          end;
          Exit(True);
        end;
      end;
      Inc(J);
    end;

    { An unstored SQL property has the same value as TFDQuery.SQL.Text: empty. }
    AText := '';
    Exit(True);
  end;
end;

function EnumDfmResourceName(AHandle: HMODULE; AType, AName: PChar;
  AParam: NativeInt): BOOL; stdcall;
var
  LNames: TStringList;
begin
  Result := True;
  if (NativeUInt(AName) shr 16) = 0 then
    Exit;

  LNames := TStringList(Pointer(AParam));
  LNames.Add(string(AName));
end;

function EnumDfmModule(Instance: THandle; Data: Pointer): Boolean;
begin
  Result := TPesquisaApi(Data).ScanModule(Instance);
end;

{ TPesquisaApi }

constructor TPesquisaApi.Create(const AFormName, AQueryName: string);
begin
  inherited Create;
  FFormName := UnqualifiedName(AFormName);
  FQueryName := Trim(AQueryName);
end;

function TPesquisaApi.InspectResource(const AModule: THandle;
  const AResourceName: string): Boolean;
var
  LResource: TResourceStream;
  LText: TMemoryStream;
  LLines: TStringList;
  LMagic: array[0..3] of AnsiChar;
  LRootName: string;
  LRootClass: string;
  LFoundQuery: Boolean;
  LWrongType: Boolean;
  LMalformed: Boolean;
begin
  Result := False;
  LResource := nil;
  LText := nil;
  LLines := nil;
  try
    try
      LResource := TResourceStream.Create(AModule, AResourceName, RT_RCDATA);
      if LResource.Size < SizeOf(LMagic) then
        Exit;

      LResource.ReadBuffer(LMagic, SizeOf(LMagic));
      if (LMagic[0] <> 'T') or (LMagic[1] <> 'P') or
        (LMagic[2] <> 'F') or (LMagic[3] <> '0') then
        Exit;

      LResource.Position := 0;
      LText := TMemoryStream.Create;
      ObjectBinaryToText(LResource, LText);
      LText.Position := 0;

      LLines := TStringList.Create;
      LLines.LoadFromStream(LText);
      if (LLines.Count = 0) or
        not TryParseComponentHeader(LLines[0], LRootName, LRootClass) or
        not FormNameMatches(FFormName, AResourceName, LRootName, LRootClass) then
        Exit;

      FFoundForm := True;
      if TryExtractSql(LLines, FQueryName, FSqlText, LFoundQuery,
        LWrongType, LMalformed) then
      begin
        FFoundQuery := True;
        FSuccess := True;
        Exit(True);
      end;

      FFoundQuery := FFoundQuery or LFoundQuery;
      FWrongQueryType := FWrongQueryType or LWrongType;
      FMalformedSql := FMalformedSql or LMalformed;
    except
      on E: EOutOfMemory do
        raise;
      on Exception do
        Exit(False);
    end;
  finally
    LLines.Free;
    LText.Free;
    LResource.Free;
  end;
end;

function TPesquisaApi.ScanModule(const AModule: THandle): Boolean;
var
  I: Integer;
  LNames: TStringList;
begin
  Result := True;
  if AModule = 0 then
    Exit;

  LNames := TStringList.Create;
  try
    EnumResourceNames(AModule, RT_RCDATA, @EnumDfmResourceName,
      NativeInt(Pointer(LNames)));
    for I := 0 to LNames.Count - 1 do
      if InspectResource(AModule, LNames[I]) then
        Exit(False);
  finally
    LNames.Free;
  end;
end;

function TPesquisaApi.Execute(out AText, AError: string): Boolean;
begin
  AText := '';
  AError := '';
  EnumResourceModules(EnumDfmModule, Self);

  Result := FSuccess;

  if Result then
  begin
    AText := FSqlText;
    Exit;
  end;

  if not FFoundForm then
    AError := Format('Form "%s" was not found in the application''s embedded DFM resources.',
      [FFormName])
  else if FWrongQueryType then
    AError := Format('Component "%s" on form "%s" is not a TFDQuery.',
      [FQueryName, FFormName])
  else if FMalformedSql then
    AError := Format('The embedded SQL for "%s.%s" could not be decoded.',
      [FFormName, FQueryName])
  else
    AError := Format('TFDQuery "%s" was not found on form "%s".',
      [FQueryName, FFormName]);
end;

{ Head::TLeitorQuery }

constructor TLeitorQuery.Create;
begin

end;

destructor TLeitorQuery.Destroy;
begin
  inherited;
end;

class function TLeitorQuery.New: ILeitorQuery;
begin
  Result := Self.Create;
end;

{ Body::TLeitorQuery }

function TLeitorQuery.Form(
  const AFormName: string): ILeitorQuery;
begin
  Result := Self;
  FFormName := Trim(AFormName);
end;

function TLeitorQuery.Query(
  const AQueryName: string): ILeitorQuery;
begin
  Result := Self;
  FQueryName := Trim(AQueryName);
end;

function TLeitorQuery._ReadCore(out AText, AError: string): Boolean;
var
  LSearch: TPesquisaApi;
begin
  AText := '';
  AError := '';
  if FFormName = '' then
  begin
    AError := 'A form name is required. Call FromForm first.';
    Exit(False);
  end;
  if FQueryName = '' then
  begin
    AError := 'A TFDQuery name is required. Call FromQuery first.';
    Exit(False);
  end;

  LSearch := TPesquisaApi.Create(FFormName, FQueryName);
  try
    Result := LSearch.Execute(AText, AError);
  finally
    LSearch.Free;
  end;
end;

function TLeitorQuery.SQLText: string;
var
  LError: string;
begin
  if not _ReadCore(Result, LError) then
    raise ELeitorQuery.Create(LError);
end;

function TLeitorQuery.TrySQLText(out AText: string): Boolean;
var
  LError: string;
begin
  Result := _ReadCore(AText, LError);
end;

end.
