import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_raw_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Đăng nhập và gọi API QLĐT trong phiên WebView.
/// Không trích xuất mật khẩu, cookie hoặc token ra Dart.
class QldtWebViewPage extends StatefulWidget {
  const QldtWebViewPage({required this.portalUrl, this.onScheduleJson, super.key});
  final String portalUrl;
  final Future<void> Function(String rawJson)? onScheduleJson;

  static bool isAllowed(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'phenikaa-uni.edu.vn' || host.endsWith('.phenikaa-uni.edu.vn');
  }

  @override
  State<QldtWebViewPage> createState() => _QldtWebViewPageState();
}

class _QldtWebViewPageState extends State<QldtWebViewPage> {
  String status = 'Đăng nhập QLĐT để tự lấy lịch học.';
  InAppWebViewController? _controller;
  Timer? _readinessTimer;
  Timer? _timeout;
  bool _syncing = false;
  bool _completed = false;
  bool _checking = false;
  int _tries = 0;

  @override
  void dispose() {
    _readinessTimer?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _checkReady() async {
    if (!mounted || _syncing || _completed || _checking) return;
    final controller = _controller;
    if (controller == null) return;
    _checking = true;
    try {
      final url = await controller.getUrl();
      if (url == null || !QldtWebViewPage.isAllowed(url.toString()) ||
          !url.host.toLowerCase().contains('qldt')) return;
      final ready = await controller.evaluateJavascript(
        source: r'''(function () {
          const s = window.edu && window.edu.system;
          return !!(s && s.userId && s.iM != null &&
                    typeof s.makeRequest === 'function');
        })();''',
      );
      if (ready != true || !mounted) return;
      _syncing = true;
      _readinessTimer?.cancel();
      setState(() => status = 'Đang tải lịch cá nhân từ QLĐT...');
      _timeout = Timer(const Duration(seconds: 75), () {
        if (mounted && _syncing) _error('QLĐT phản hồi quá lâu.');
      });
      await controller.evaluateJavascript(source: _syncScript);
    } on Object {
      if (mounted) _error('Không lấy được dữ liệu QLĐT.');
    } finally {
      _checking = false;
    }
  }

  void _scheduleCheck() {
    if (_syncing || _completed) return;
    _readinessTimer?.cancel();
    _tries = 0;
    _readinessTimer = Timer.periodic(
      const Duration(milliseconds: 750),
      (timer) {
        if (!mounted || _syncing || _completed || _tries++ > 100) {
          timer.cancel();
          return;
        }
        unawaited(_checkReady());
      },
    );
    unawaited(_checkReady());
  }

  void _error(String message) {
    _timeout?.cancel();
    _readinessTimer?.cancel();
    _syncing = false;
    if (mounted) setState(() => status = message);
  }

  Future<void> _received(List<dynamic> args) async {
    if (!mounted || !_syncing || args.isEmpty) return;
    try {
      final document = QldtRawDocument.fromJsonText(args[0].toString());
      final value = jsonDecode(document.text) as Map<String, dynamic>;
      final count = (value['Data'] as List<dynamic>).length;
      if (count == 0) {
        _error('QLĐT chưa trả lịch của học kỳ này.');
        return;
      }
      if (widget.onScheduleJson != null) {
        await widget.onScheduleJson!(document.text);
      }
      _completed = true;
      _syncing = false;
      _timeout?.cancel();
      if (mounted) {
        setState(() {
          status = 'Đã nhận ' + count.toString() + ' buổi từ QLĐT.';
        });
      }
    } on Object {
      _error('Dữ liệu QLĐT không hợp lệ, giữ nguyên lịch offline.');
    }
  }

  void _onCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'coocScheduleResult',
      callback: _received,
    );
    controller.addJavaScriptHandler(
      handlerName: 'coocScheduleError',
      callback: (args) {
        if (mounted && _syncing && args.isNotEmpty) {
          _error(args.first.toString());
        }
        return null;
      },
    );
  }

  static const String _syncScript = r'''
    (function () {
      const s = window.edu && window.edu.system;
      const b = window.flutter_inappwebview;
      if (!s || !s.userId || s.iM == null ||
          !b || typeof b.callHandler !== 'function' ||
          typeof s.makeRequest !== 'function') return 'SESSION_EXPIRED';
      let done = false;
      const fail = reason => {
        if (done) return;
        done = true;
        b.callHandler('coocScheduleError', reason);
      };
      const call = (action, func, fields, next) => {
        if (done) return;
        const data = Object.assign({
          action:action, func:func, iM:s.iM,
          strQLSV_NguoiHoc_Id:s.userId
        }, fields);
        try {
          s.makeRequest({
            success: response => {
              if (done) return;
              if (!response || response.Success !== true ||
                  !Array.isArray(response.Data)) {
                fail('QLĐT trả dữ liệu không hợp lệ.');
                return;
              }
              try { next(response.Data); }
              catch (_) { fail('Không xử lý được dữ liệu QLĐT.'); }
            },
            error: () => fail('Lỗi kết nối QLĐT.'),
            type:'POST',action:action,contentType:true,data:data,fakedb:[]
          },false,false,false,null);
        } catch (_) { fail('QLĐT từ chối yêu cầu đồng bộ.'); }
      };
      const timeAction = 'DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P';
      const planAction = 'DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv';
      const regAction = 'DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP';
      const scheduleAction = 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv';
      const parseDate = value => {
        const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(value || ''));
        if (!m) return null;
        const d = new Date(+m[3], +m[2]-1, +m[1]);
        return d.getFullYear() === +m[3] && d.getMonth() === +m[2]-1 &&
          d.getDate() === +m[1] ? d : null;
      };
      const format = d => String(d.getDate()).padStart(2,'0') + '/' +
        String(d.getMonth()+1).padStart(2,'0') + '/' + d.getFullYear();
      call(timeAction, 'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan',
        {strDaoTao_ThoiGianDaoTao_Id:null}, terms => {
        const semesters = terms.map(row => {
          const m = /^(\d{4})_(\d{4})_(\d+)$/.exec(String(row.THOIGIAN || ''));
          return m && row.ID && +m[2] === +m[1] + 1 ?
            {id:row.ID,name:row.THOIGIAN,year:+m[2],term:+m[3]} : null;
        }).filter(Boolean).sort((a,b) => b.year-a.year || b.term-a.term);
        if (!semesters.length) { fail('Không tìm thấy học kỳ.'); return; }
        const semester = semesters[0];
        call(planAction, 'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan',
          {strDaoTao_ThoiGianDaoTao_Id:semester.id}, plans => {
          const matches = plans.filter(row => row && row.ID &&
            (String(row.MAKEHOACH || '') === semester.name ||
             String(row.MAKEHOACH || '').startsWith(semester.name + ',')));
          const ids = [...new Set(matches.map(row => String(row.ID)))];
          if (ids.length !== 1) {
            fail('Không xác định được kế hoạch học kỳ.'); return;
          }
          call(regAction, 'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan',{
            strDaoTao_ChuongTrinh_Id:'',
            strDangKy_KeHoachDangKy_Id:ids[0],
            strNguoiThucHien_Id:s.userId,
            strDaoTao_ThoiGianDaoTao_Id:semester.id
          }, rows => {
            const starts = rows.map(row => parseDate(row.NGAYBATDAU))
              .filter(Boolean).sort((a,b) => a-b);
            if (!starts.length) {
              fail('Chưa có lớp đăng ký để lấy lịch.'); return;
            }
            const start = starts[0];
            const end = new Date(start.getFullYear(),
              start.getMonth()+4,start.getDate()+7);
            const chunks = [];
            for (let d=new Date(start);d<=end;) {
              const last = new Date(d);
              last.setDate(last.getDate()+6);
              if (last>end) last.setTime(end.getTime());
              chunks.push({start:format(d),end:format(last)});
              d=new Date(last);
              d.setDate(d.getDate()+1);
            }
            let active=0,cursor=0,finished=0;
            const all=[];
            const finalize=() => {
              if (done || finished!==chunks.length) return;
              done=true;
              b.callHandler('coocScheduleResult', JSON.stringify({
                Data:all,
                user:{studentId:String(s.userId),displayName:'Sinh viên'},
                semester:{id:semester.id,name:semester.name,
                  startDate:start.toISOString(),endDate:end.toISOString()}
              }));
            };
            const launch=() => {
              if (done) return;
              while (active<6 && cursor<chunks.length) {
                const week=chunks[cursor++];
                active++;
                call(scheduleAction,
                  'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',{
                  strNgayBatDau:week.start,
                  strNgayKetThuc:week.end
                }, records => {
                  active--;
                  finished++;
                  if (all.length+records.length>10000) {
                    fail('QLĐT trả quá nhiều bản ghi.'); return;
                  }
                  all.push(...records);
                  launch();
                  finalize();
                });
              }
              finalize();
            };
            launch();
          });
        });
      });
      return 'REQUESTED';
    })();
  ''';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập QLĐT'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Đồng bộ lại',
            onPressed: () {
              _completed = false;
              _error('Đang kiểm tra phiên QLĐT...');
              _scheduleCheck();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(children: <Widget>[
        Padding(padding: const EdgeInsets.all(12), child: Text(status)),
        Expanded(child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.portalUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
          ),
          onWebViewCreated: _onCreated,
          onLoadStop: (controller, url) => _scheduleCheck(),
          onUpdateVisitedHistory: (controller, url, _) => _scheduleCheck(),
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame == true && mounted) {
              setState(() => status = 'Không tải được trang. Kiểm tra mạng và URL.');
            }
          },
        )),
      ]),
    );
  }
}
