unit uFrmPesquisaFlutuante;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.OleCtrls,
  SHDocVw,
  Winapi.ActiveX,
  Rtti,
  TypInfo,
  Vcl.StdCtrls,
  System.StrUtils,
  System.JSON,
  System.Threading,
  System.Generics.Collections,
  MSHTML,
  Vcl.ExtCtrls,
  Winapi.WebView2,
  Vcl.Edge;

type
  TfrmPesquisaFlutuante = class(TForm)
    Move: TPanel;
    Core: TEdgeBrowser;
    procedure MoveMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CoreWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    function GetForms: String;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FInstance: TForm;

    procedure OpenFormByClassName(const AClassName: string);
  public
  end;

var
  frmPesquisaFlutuante: TfrmPesquisaFlutuante;
  GFormsJSON: string = '';

implementation

{$R *.dfm}

uses
  UfrmLogin,
  uWebView2.Setup;

const
  cAction        = 'action';
  cData          = 'data';
  cGetData       = 'try_data';
  cClose         = 'close_form';
  cOpenForm      = 'open_form';
  cOpenUtil      = 'open_util';
  cBypassPasswrd = 'password';

  HTML = '''
  <html lang="en">
  <head>
      <meta charset="UTF-8" />
      <meta http-equiv="X-UA-Compatible" content="IE=11" />
      <title>Pesquisa Flutuante</title>
      <style>
          * {
              box-sizing: border-box;
              margin: 0;
              padding: 0;
          }

          html,
          body {
              height: 100%;
              width: 100%;
              background: #19191c;
              margin: 0;
          }

          body {
              display: flex;
              align-items: center;
              justify-content: center;
              font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
          }

          .search-panel {
              width: 100%;
              height: 100%;
              background: #19191c;
              border: 1px solid rgba(255, 255, 255, 0.06);
              border-radius: 10px;
              overflow: hidden;
              display: -ms-flexbox;
              display: flex;
              -ms-flex-direction: column;
              flex-direction: column;
          }

          .search-panel__row {
              display: -ms-flexbox;
              display: flex;
              -ms-flex-align: center;
              align-items: center;
              -ms-flex-pack: justify;
              justify-content: space-between;
          }

          .search-panel__header {
              padding: 16px 18px;
          }

          .search-panel__title {
              color: #f5f5f7;
              font-size: 15px;
              font-weight: 600;
          }

          .search-panel__close {
              background: transparent;
              border: 0;
              padding: 4px;
              cursor: pointer;
              color: #8b8b93;
              line-height: 0;
          }

          .search-panel__close:hover {
              color: #d4d4d8;
          }

          .search-panel__divider {
              height: 1px;
              background: rgba(255, 255, 255, 0.08);
              border: 0;
          }

          .search-panel__body {
              padding: 14px 18px;
          }

          .search-panel__input-wrap {
              display: -ms-flexbox;
              display: flex;
              -ms-flex-align: center;
              align-items: center;
              background: #232326;
              border: 1px solid rgba(255, 255, 255, 0.06);
              border-radius: 8px;
              padding: 9px 12px;
          }

          .search-panel__input-wrap svg {
              -ms-flex-negative: 0;
              flex-shrink: 0;
              margin-right: 10px;
              color: #6f6f78;
          }

          .search-panel__input {
              -ms-flex: 1;
              flex: 1;
              background: transparent;
              border: 0;
              outline: 0;
              color: #f0f0f2;
              font-size: 14px;
          }

          .search-panel__input::-ms-input-placeholder {
              color: #6f6f78;
          }

          .search-panel__input::placeholder {
              color: #6f6f78;
          }

          .search-panel__item {
              display: -ms-flexbox;
              display: flex;
              -ms-flex-align: center;
              align-items: center;

              padding: 9px 10px;
              border-radius: 6px;
              cursor: pointer;
              font-size: 13px;
          }

          .search-panel__item:hover {
              background: #232326;
              color: #f5f5f7;
          }

          .search-panel__item-caption {
              -ms-flex: 1;
              flex: 1;

              min-width: 0;
              overflow: hidden;
              white-space: nowrap;
              text-overflow: ellipsis;

              color: #d4d4d8;

              font-size: 13px;
          }

          .search-panel__item-class {
              -ms-flex-negative: 0;
              flex-shrink: 0;

              margin-left: 6px;
              color: #6f6f78;
              font-size: 11px;
          }

          .search-panel__item--fluent .search-panel__item-caption {
              color: #e8c14c;
          }

          .search-panel__item--fluent .search-panel__item-class {
              color: #b89638;
          }

          .search-panel__item--fluent:hover {
              background: rgba(232, 193, 76, 0.10);
          }

          .search-panel__footer {
              padding: 12px 18px;
          }

          .search-panel__count {
              color: #8b8b93;
              font-size: 13px;
          }

          .search-panel__results-wrap {
              position: relative;
              flex: 1;
              margin: 0 10px;
              overflow: hidden;
          }

          .search-panel__results {
              position: absolute;
              top: 0;
              left: 0;
              right: -18px;
              bottom: 0;

              overflow-y: auto;
              overflow-x: hidden;

              list-style: none;
              padding: 0 8px;
              padding-right: 26px;
          }

          .search-panel__scrollbar-track {
              position: absolute;
              top: 4px;
              bottom: 4px;
              right: 2px;
              width: 5px;
          }

          .search-panel__scrollbar-thumb {
              position: absolute;
              right: 0;
              width: 5px;
              border-radius: 10px;
              background: #3a3a40;
              transition: background 0.15s;
              cursor: pointer;
          }

          .search-panel__scrollbar-thumb:hover {
              background: #55555c;
          }

          .search-panel__count {
              display: flex;
              align-items: center;
              color: #8b8b93;
              font-size: 13px;
          }

          .search-panel__spinner {
              width: 12px;
              height: 12px;
              margin-right: 8px;
              border: 2px solid rgba(255, 255, 255, 0.15);
              border-top-color: #8b8b93;
              border-radius: 50%;
              animation: spinnerRotate .8s linear infinite;
          }

          @keyframes spinnerRotate {
              from {
                  transform: rotate(0deg);
              }
              to {
                  transform: rotate(360deg);
              }
          }

          .search-panel__skeleton-item {
              padding: 9px 10px;
          }

          .search-panel__skeleton-bar {
              display: block;
              height: 12px;
              border-radius: 4px;

              background: linear-gradient(90deg,
                      #232326 25%,
                      #2c2c30 37%,
                      #232326 63%);
              background-size: 400% 100%;
              animation: skeletonShimmer 1.4s ease infinite;
          }

          .search-panel__skeleton-bar--caption {
              -ms-flex: 1;
              flex: 1;
              margin-right: 10px;
          }

          .search-panel__skeleton-bar--class {
              -ms-flex-negative: 0;
              flex-shrink: 0;
              width: 38px;
          }

          @keyframes skeletonShimmer {
              0% {
                  background-position: 100% 50%;
              }
              100% {
                  background-position: 0% 50%;
              }
          }

          /* ---- key icon in footer ---- */
          .search-panel__key-link {
              display: inline-flex;
              align-items: center;
              justify-content: center;
              color: #6f6f78;
              transition: color 0.2s, transform 0.2s;
              padding: 4px;
              border-radius: 6px;
              line-height: 0;
              text-decoration: none;
          }

          .search-panel__key-link:hover {
              color: #d4d4d8;
              transform: scale(1.05);
          }

          .search-panel__key-link:active {
              transform: scale(0.92);
          }

          .search-panel__footer-right {
              display: flex;
              align-items: center;
              gap: 8px;
          }
      </style>
  </head>
  <body>

      <div class="search-panel" role="dialog" aria-label="Pesquisa Flutuante">
          <!-- header -->
          <div class="search-panel__row search-panel__header">
              <span class="search-panel__title">Pesquisa</span>
              <button type="button" class="search-panel__close" aria-label="Close" id="closeBtn">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                      <path d="M3 3L13 13M13 3L3 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                  </svg>
              </button>
          </div>

          <hr class="search-panel__divider" />

          <!-- search input -->
          <div class="search-panel__body">
              <div class="search-panel__input-wrap">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                      <circle cx="7" cy="7" r="5" stroke="currentColor" stroke-width="1.5" />
                      <path d="M11 11L14.5 14.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                  </svg>
                  <input type="text" class="search-panel__input" id="searchInput" autocomplete="off" />
              </div>
          </div>

          <!-- results -->
          <div class="search-panel__results-wrap">
              <ul class="search-panel__results" id="resultsList"></ul>

              <div class="search-panel__scrollbar-track">
                  <div class="search-panel__scrollbar-thumb" id="scrollbarThumb"></div>
              </div>
          </div>

          <hr class="search-panel__divider" />

          <!-- footer with key icon on the right -->
          <div class="search-panel__row search-panel__footer">
              <div class="search-panel__count">
                  <span id="loadingSpinner" class="search-panel__spinner"></span>
                  <span id="resultCount">Carregando...</span>
              </div>

              <div class="search-panel__footer-right">
                  <a class="search-panel__key-link" aria-label="Password" onclick="window.chrome.webview.postMessage({ action: 'password' }); return false;">
                      <!-- Improved horizontal key SVG -->
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <!-- key head (bow) -->
                          <circle cx="6" cy="12" r="4" />
                          <!-- hole in head -->
                          <circle cx="6" cy="12" r="2" fill="none" />
                          <!-- shaft -->
                          <line x1="10" y1="12" x2="19" y2="12" />
                          <!-- teeth (bits) -->
                          <path d="M14 12 L14 9 M16 12 L16 8 M18 12 L18 10" />
                      </svg>
                  </a>
              </div>
          </div>
      </div>

      <script>
          (function() {
              "use strict";

              var formsData = [];
              var isLoaded = false;

              var spinner = document.getElementById("loadingSpinner");
              var input = document.getElementById("searchInput");
              var countEl = document.getElementById("resultCount");
              var closeBtn = document.getElementById("closeBtn");
              var resultsList = document.getElementById("resultsList");
              var scrollbarThumb = document.getElementById("scrollbarThumb");
              var isDraggingThumb = false;
              var dragStartY = 0;
              var dragStartScrollTop = 0;

              var SKELETON_WIDTHS = ["20%", "65%", "42%", "35%", "40%", "28%"];

              function escapeHtml(s) {
                  return String(s)
                      .replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;");
              }

              function renderSkeleton(count) {
                  var html = "";
                  var i, width;

                  for (i = 0; i < count; i++) {
                      width = SKELETON_WIDTHS[Math.floor(Math.random() * SKELETON_WIDTHS.length)];

                      html +=
                          '<li class="search-panel__skeleton-item">' +
                          '<span class="search-panel__skeleton-bar" style="width:' + width + '"></span>' +
                          '</li>';
                  }

                  resultsList.innerHTML = html;
                  scrollbarThumb.style.display = "none";
              }

              function renderResults(filter) {
                  if (!isLoaded) {
                      return;
                  }

                  var query = filter.toLowerCase();
                  var html = "";
                  var count = 0;
                  var i, item, kind, itemClass;

                  for (i = 0; i < formsData.length; i++) {
                      item = formsData[i];
                      if (query === "" ||
                          item.caption.toLowerCase().indexOf(query) !== -1 ||
                          item.cls.toLowerCase().indexOf(query) !== -1) {
                          count = count + 1;

                          kind = item.kind || "form";
                          itemClass = "search-panel__item" + (kind === "util" ? " search-panel__item--fluent" : "");

                          html += '<li class="' + itemClass + '" data-class="' +
                              escapeHtml(item.cls) + '" data-kind="' + escapeHtml(kind) + '" title="' + escapeHtml(item
                                  .caption) + '">' +
                              '<span class="search-panel__item-caption">' + escapeHtml(item.caption) + '</span>' +
                              '<span class="search-panel__item-class">' + escapeHtml(item.cls) + '</span>' +
                              '</li>';
                      }
                  }

                  resultsList.innerHTML = html;
                  countEl.textContent = count + (count === 1 ? " resultado encontrado." : " resultados encontrados.");

                  updateScrollbarThumb();
              }

              function updateScrollbarThumb() {
                  var track = document.querySelector(".search-panel__scrollbar-track");
                  var trackHeight = track.clientHeight;
                  var contentHeight = resultsList.scrollHeight;

                  if (contentHeight <= trackHeight) {
                      scrollbarThumb.style.display = "none";
                      return;
                  }

                  scrollbarThumb.style.display = "block";

                  var thumbHeight = Math.max(20, (trackHeight / contentHeight) * trackHeight);
                  var maxThumbTop = trackHeight - thumbHeight;
                  var scrollRatio = resultsList.scrollTop / (contentHeight - trackHeight);
                  var thumbTop = scrollRatio * maxThumbTop;

                  scrollbarThumb.style.height = thumbHeight + "px";
                  scrollbarThumb.style.top = thumbTop + "px";
              }

              function onThumbMouseDown(e) {
                  var ev = e || window.event;
                  isDraggingThumb = true;
                  dragStartY = ev.clientY;
                  dragStartScrollTop = resultsList.scrollTop;
                  if (ev.preventDefault) ev.preventDefault();
              }

              function onDocumentMouseMove(e) {
                  if (!isDraggingThumb) return;

                  var ev = e || window.event;
                  var track = document.querySelector(".search-panel__scrollbar-track");
                  var trackHeight = track.clientHeight;
                  var contentHeight = resultsList.scrollHeight;

                  var deltaY = ev.clientY - dragStartY;
                  var scrollDelta = (deltaY / trackHeight) * contentHeight;

                  resultsList.scrollTop = dragStartScrollTop + scrollDelta;
              }

              function onDocumentMouseUp() {
                  isDraggingThumb = false;
              }

              function handleItemClick(e) {
                  var ev = e || window.event;
                  var target = ev.target || ev.srcElement;

                  while (target && target !== resultsList && !target.getAttribute("data-class")) {
                      target = target.parentNode;
                  }

                  if (target && target !== resultsList) {
                      var cls = target.getAttribute("data-class");
                      var kind = target.getAttribute("data-kind") || "form";

                      window.chrome.webview.postMessage({
                          action: kind === "util" ? "open_util" : "open_form",
                          data: cls
                      });
                  }
              }

              if (input.addEventListener) {
                  input.addEventListener("input", function() { renderResults(input.value); });
              } else if (input.attachEvent) {
                  input.attachEvent("onpropertychange", function() { renderResults(input.value); });
              }

              if (closeBtn.addEventListener) {
                  closeBtn.addEventListener("click", function() {
                      window.chrome.webview.postMessage({
                          action: "close_form",
                          data: ""
                      });
                  });
              }

              if (resultsList.addEventListener) {
                  resultsList.addEventListener("click", handleItemClick);
              } else if (resultsList.attachEvent) {
                  resultsList.attachEvent("onclick", handleItemClick);
              }

              if (resultsList.addEventListener) {
                  resultsList.addEventListener("scroll", updateScrollbarThumb);
              } else {
                  resultsList.attachEvent("onscroll", updateScrollbarThumb);
              }

              if (scrollbarThumb.addEventListener) {
                  scrollbarThumb.addEventListener("mousedown", onThumbMouseDown);
              } else {
                  scrollbarThumb.attachEvent("onmousedown", onThumbMouseDown);
              }

              if (document.addEventListener) {
                  document.addEventListener("mousemove", onDocumentMouseMove);
                  document.addEventListener("mouseup", onDocumentMouseUp);
              } else {
                  document.attachEvent("onmousemove", onDocumentMouseMove);
                  document.attachEvent("onmouseup", onDocumentMouseUp);
              }

              document.addEventListener("keydown", function(e) {
                  e = e || window.event;

                  if (e.keyCode === 27) {
                      window.chrome.webview.postMessage({
                          action: "close_form",
                          data: ""
                      });
                  }
              });

              window.setFormsData = function(data) {
                  formsData = data;
                  isLoaded = true;
                  spinner.style.display = "none";
                  renderResults(input.value || "");
                  input.focus();
              };

              renderSkeleton(3);

              window.chrome.webview.postMessage({
                action: "try_data",
                data: ""
              });
          })();
      </script>

  </body>
  </html>
  ''';

procedure TfrmPesquisaFlutuante.MoveMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    ReleaseCapture;
    Perform(WM_SYSCOMMAND, SC_MOVE or HTCAPTION, 0);
  end;
end;

function DecodeDFMString(const S: string): string;
var
  I: Integer;
  Result_: string;
  NumStr: string;
begin
  Result_ := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '''' then
    begin
      Inc(I);
      while (I <= Length(S)) and (S[I] <> '''') do
      begin
        Result_ := Result_ + S[I];
        Inc(I);
      end;
      Inc(I);
    end
    else if S[I] = '#' then
    begin
      Inc(I);
      NumStr := '';
      while (I <= Length(S)) and CharInSet(S[I], ['0'..'9']) do
      begin
        NumStr := NumStr + S[I];
        Inc(I);
      end;
      if NumStr <> '' then
        Result_ := Result_ + Chr(StrToInt(NumStr));
    end
    else
      Inc(I);
  end;
  Result := Result_;
end;

function GetCaptionFromDFM(AClass: TClass): string;
var
  ResStream: TResourceStream;
  TextStream: TMemoryStream;
  SL: TStringList;
  I: Integer;
  Line, Raw: string;
begin
  Result := '';

  if FindResource(HInstance, PChar(AClass.ClassName), RT_RCDATA) = 0 then
    Exit;

  ResStream := TResourceStream.Create(HInstance, AClass.ClassName, RT_RCDATA);
  try
    TextStream := TMemoryStream.Create;
    try
      ObjectBinaryToText(ResStream, TextStream);
      TextStream.Position := 0;

      SL := TStringList.Create;
      try
        SL.LoadFromStream(TextStream);

        I := 1;
        while I <= SL.Count - 1 do
        begin
          Line := Trim(SL[I]);

          if Line.StartsWith('object ') or Line.StartsWith('inherited ') then
            Break;

          if (Line = 'Caption =') or Line.StartsWith('Caption = ') then
          begin
            Raw := Copy(Line, Pos('=', Line) + 1, MaxInt);
            while (Trim(Raw) = '') or Trim(Raw).EndsWith('+') do
            begin
              Inc(I);
              Raw := Raw + SL[I];
            end;
            Result := DecodeDFMString(Raw);
            Break;
          end;

          Inc(I);
        end;
      finally
        SL.Free;
      end;
    finally
      TextStream.Free;
    end;
  finally
    ResStream.Free;
  end;
end;

function IsFluentBuilderType(Typ: TRttiType): Boolean;
var
  M: TRttiMethod;
begin
  Result := False;
  if (Typ = nil) or (not (Typ is TRttiInstanceType)) then
    Exit;

  if TRttiInstanceType(Typ).MetaclassType.InheritsFrom(TForm) then
    Exit;

  M := Typ.GetMethod('New');
  Result := Assigned(M) and M.IsClassMethod and (Length(M.GetParameters) = 0);
end;

function FriendlyNameFromClass(const AClassName: string): string;
begin
  Result := AClassName;
  if Result.StartsWith('T') then
    Result := Copy(Result, 2, MaxInt);
end;

function BuildFormsJSON: string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Arr: TJSONArray;
  Obj: TJSONObject;
  Cls: TClass;
  Caption: string;
begin
  Ctx := TRttiContext.Create;
  Arr := TJSONArray.Create;
  try
    for Typ in Ctx.GetTypes do
    begin
      if Typ.TypeKind <> tkClass then
        Continue;

      Cls := Typ.AsInstance.MetaclassType;
      if Cls = nil then
        Continue;

      if Cls.InheritsFrom(TForm) and (Cls <> TForm) then
      begin
        if FindResource(HInstance, PChar(Cls.ClassName), RT_RCDATA) = 0 then
          Continue;

        Caption := GetCaptionFromDFM(Cls);
        if Caption = '' then
          Caption := Typ.Name;

        Obj := TJSONObject.Create;
        Obj.AddPair('cls', Typ.Name);
        Obj.AddPair('caption', Caption);
        Obj.AddPair('kind', 'form');
        Arr.Add(Obj);
        Continue;
      end;

      if IsFluentBuilderType(Typ) then
      begin
        Obj := TJSONObject.Create;
        Obj.AddPair('cls', Typ.Name);
        Obj.AddPair('caption', FriendlyNameFromClass(Typ.Name));
        Obj.AddPair('kind', 'util');
        Arr.Add(Obj);
      end;
    end;

    Result := Arr.ToJSON;
  finally
    Arr.Free;
  end;
end;

procedure TfrmPesquisaFlutuante.OpenFormByClassName(const AClassName: string);
var
  Ctx: TRttiContext;
  Typ: TRttiType;
begin
  Ctx := TRttiContext.Create;
  for Typ in Ctx.GetTypes do
  begin
    if (Typ.TypeKind = tkClass) and
       (Typ.Name = AClassName) and
       (Typ.AsInstance.MetaclassType <> TForm) and
       Typ.AsInstance.MetaclassType.InheritsFrom(TForm) then
    begin
      try
        if Assigned(FInstance) then
        begin
          FInstance.Close;
          FInstance.Free;
        end;

        FInstance := TFormClass(Typ.AsInstance.MetaclassType).Create(Application);
        FInstance.Show;
      except
        on E: Exception do
          MessageDlg('Erro ao abrir ' + AClassName + ': ' + E.Message,
            mtError, [mbOK], 0);
      end;
      Exit;
    end;
  end;
end;

procedure SimulateFluentClass(const AClassName: string);
var
  Ctx: TRttiContext;
  T, Typ, CurType: TRttiType;
  NewMethod, Meth: TRttiMethod;
  CurValue, NextValue: TValue;
  DeclaredMethods: TArray<TRttiMethod>;
  Executed: Boolean;
  SafetyCounter: Integer;

  function IsEligible(AMethod: TRttiMethod): Boolean;
  begin
    Result :=
      (AMethod.Visibility = mvPublic) and
      (Length(AMethod.GetParameters) = 0) and
      (not AMethod.IsClassMethod) and
      (not AMethod.IsConstructor) and
      (not AMethod.IsDestructor) and
      (not AMethod.Name.StartsWith('Get')) and
      (not AMethod.Name.StartsWith('Set')) and
      (not SameText(AMethod.Name, 'Free')) and
      (not SameText(AMethod.Name, 'DisposeOf')) and
      (not SameText(AMethod.Name, 'ToString')) and
      (not SameText(AMethod.Name, 'Equals')) and
      (not SameText(AMethod.Name, 'GetHashCode'));
  end;

begin
  Ctx := TRttiContext.Create;

  Typ := nil;
  for T in Ctx.GetTypes do
    if (T.TypeKind = tkClass) and (T.Name = AClassName) then
    begin
      Typ := T;
      Break;
    end;

  if not IsFluentBuilderType(Typ) then
  begin
    MessageDlg('Classe "' + AClassName + '" não segue a convenção fluente ' +
      '(método de classe "New" não encontrado).', mtWarning, [mbOK], 0);
    Exit;
  end;

  NewMethod := Typ.GetMethod('New');
  try
    CurValue := NewMethod.Invoke(Typ.AsInstance.MetaclassType, []);
  except
    on E: Exception do
    begin
      MessageDlg('Erro ao chamar New em ' + AClassName + ': ' + E.Message,
        mtError, [mbOK], 0);
      Exit;
    end;
  end;

  if CurValue.IsEmpty then
    Exit;

  CurType := Ctx.GetType(CurValue.TypeInfo);
  if CurType = nil then
    Exit;

  if (CurType.TypeKind = tkInterface) and (Length(CurType.GetMethods) = 0) then
  begin
    MessageDlg('A interface "' + CurType.Name + '" retornada por New não expõe RTTI de métodos. ' +
      'Faça-a herdar de IInvokable (ou compile com {$M+}) para permitir a simulação automática.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  SafetyCounter := 0;
  repeat
    Inc(SafetyCounter);
    if SafetyCounter > 50 then
      Break;

    Executed := False;
    DeclaredMethods := CurType.GetMethods;

    for Meth in DeclaredMethods do
    begin
      if not IsEligible(Meth) then
        Continue;

      try
        if CurValue.IsObject then
          NextValue := Meth.Invoke(CurValue.AsObject, [])
        else
          NextValue := Meth.Invoke(CurValue, []);
      except
        on E: Exception do
        begin
          MessageDlg('Erro ao chamar ' + Meth.Name + ' em ' + CurType.Name +
            ': ' + E.Message, mtError, [mbOK], 0);
          Exit;
        end;
      end;

      Executed := True;

      if SameText(Meth.Name, 'Show') then
        Exit;

      if not NextValue.IsEmpty then
      begin
        CurValue := NextValue;
        CurType := Ctx.GetType(CurValue.TypeInfo);
      end;

      Break;
    end;

  until not Executed;
end;

function FindForm(AClass: TFormClass): TForm;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].ClassType = AClass then
      Exit(Screen.Forms[I]);
end;

function Dict(Args: TWebMessageReceivedEventArgs): TDictionary<string,string>;
var
  P: PWideChar;
  J: TJSONObject;
  Pair: TJSONPair;
begin
  Result := TDictionary<string,string>.Create;
  P := nil;
  try
    Args.ArgsInterface.Get_webMessageAsJson(P);
    J := TJSONObject.ParseJSONValue(string(P)) as TJSONObject;
    try
      for Pair in J do
        Result.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
    finally
      J.Free;
      CoTaskMemFree(P);
    end;
  except
    Result.Free;
    raise Exception.Create('Erro fazendo Parsing :: Json -> Dict');
  end;
end;

procedure RodarAsync(const AProc: TProc);
begin
  TThread.Queue(nil, procedure begin AProc(); end);
end;

procedure TfrmPesquisaFlutuante.CoreWebMessageReceived(
  Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
begin
  var Json := Dict(Args);

  if ContainsText(Json[cAction], cGetData) then
  begin
    GetForms;

    Core.SetFocus;
    RodarAsync(procedure begin Core.ExecuteScript('window.setFormsData(' + GFormsJSON + ');'); end);
  end;

  if ContainsText(Json[cAction], cClose) then
  begin
    Hide;
    Close;
  end;

  if ContainsText(Json[cAction], cOpenForm) then
  begin
    Hide;
    RodarAsync(procedure begin OpenFormByClassName(Json[cData]); end);
    Close;
  end;

  if ContainsText(Json[cAction], cOpenUtil) then
  begin

    RodarAsync(procedure begin SimulateFluentClass(Json[cData]); end);
  end;

  if ContainsText(Json[cAction], cBypassPasswrd) then
  begin
    Hide;
    var Form := FindForm(TfrmLogin) as TfrmLogin;
    if Assigned(Form) then
    begin
      Form.edtSenha.Text := '8417200812';
      Form.imgLogin.OnClick(nil);
    end;

    Close;
  end;
end;

function TfrmPesquisaFlutuante.GetForms: String;
begin
  Result := GFormsJSON;

  if Trim(GFormsJSON) <> '' then
    Exit;

  GFormsJSON := BuildFormsJSON;
end;

procedure SetEdgeBackground(Edge: TCustomEdgeBrowser; Color: TColor);
var
  Controller2: ICoreWebView2Controller2;
  CustomColor: COREWEBVIEW2_COLOR;
  RGB: COLORREF;
  HR: HRESULT;
begin
  if (Edge = nil) or (Edge.ControllerInterface = nil) then
    Exit;

  if Succeeded(Edge.ControllerInterface.QueryInterface(IID_ICoreWebView2Controller2, Controller2)) then
  begin
    RGB := ColorToRGB(Color);

    CustomColor.A := 255;
    CustomColor.R := GetRValue(RGB);
    CustomColor.G := GetGValue(RGB);
    CustomColor.B := GetBValue(RGB);

    HR := Controller2.Set_DefaultBackgroundColor(CustomColor);
  end;
end;

procedure TfrmPesquisaFlutuante.FormCreate(Sender: TObject);
var
  Settings3: ICoreWebView2Settings3;
  Rgn: HRGN;
begin
  if not NovoWebView2Setup.Instalar then
  begin
    ShowMessage('Não foi possível preparar o Microsoft WebView2 Runtime.');
    Exit;
  end;

  Core.AdditionalBrowserArguments :=
//  '--disable-features=AutofillServerCommunication,AutofillEnableAccountWalletStorage,MediaRouter,OptimizationHints,Translate,InterestFeedContentSuggestions,NotificationTriggers,GlobalMediaControls,PasswordImport,PasswordManagerRedesign,SafetyCheck,CertificateTransparencyComponentUpdater ' +
//  '--no-default-browser-check ' +
//  '--no-first-run ' +
//  '--disable-domain-reliability ' +
//  '--disable-background-networking ' +
//  '--metrics-recording-only ' +
//  '--disable-breakpad ' +
  '--proxy-server="direct://" ' +
  '--proxy-bypass-list=* ' +
  '--disable-background-timer-throttling ' +
  '--disable-renderer-backgrounding ' +
  '--disable-backgrounding-occluded-windows ' +
  '--disable-features=CalculateNativeWinOcclusion ' +
  '--allow-file-access-from-files';

  Core.UserDataFolder := '';
  Core.CreateWebView;

  SetEdgeBackground(Core, $1C1919);

  while (not Core.WebViewCreated) or (not Assigned(Core.ControllerInterface)) do
    Application.ProcessMessages;

  SetEdgeBackground(Core, $1C1919);

  Core.AddWebResourceRequestedFilter('*', COREWEBVIEW2_WEB_RESOURCE_CONTEXT(0));
  Core.DefaultContextMenusEnabled := False;

  if Succeeded(Core.SettingsInterface.QueryInterface(ICoreWebView2Settings3, Settings3)) then
    Settings3.Set_AreBrowserAcceleratorKeysEnabled(Ord(False));

  Core.NavigateToString(HTML);
  SetEdgeBackground(Core,  $1C1919);

  Rgn := CreateRoundRectRgn(0, 0, ClientWidth + 1, ClientHeight + 1, 10, 10);
  SetWindowRgn(Handle, Rgn, True);
end;

procedure TfrmPesquisaFlutuante.FormDestroy(Sender: TObject);
begin
  //
end;

end.
