/* ============================================================
   起始模板脚本
   ------------------------------------------------------------
   已经处理好几件容易出事的事：
   · 事件一律 addEventListener（容器禁 onclick= 行内事件）
   · 存储读写全部 try/catch —— 隐私模式或配额满时会抛异常，不能静默丢数据
   · 解析失败时备份原始数据，绝不直接清空用户的东西
   · 日期一律按本地时区算 —— 用 UTC 会让 23:59 的操作记到第二天
   · 跨午夜同时覆盖「切后台再回前台」和「页面一直亮着」两种情况
   ============================================================ */
(function () {
  'use strict';

  var STORE_KEY = 'mytool.v1';

  /* ---------- 日期：全部本地时区 ---------- */
  function pad2(n) { return n < 10 ? '0' + n : '' + n; }
  function keyOf(d) {
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
  }
  function dateOf(key) {
    var p = key.split('-');
    // 三参数构造，避免 new Date('2026-07-21') 被当成 UTC
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }
  function todayKey() { return keyOf(new Date()); }

  /* ---------- 存储：失败不能静默 ---------- */
  var storageWorks = true;

  function load() {
    var raw = null;
    try { raw = window.localStorage.getItem(STORE_KEY); }
    catch (e) { storageWorks = false; return fresh(); }
    if (!raw) return fresh();
    try {
      var d = JSON.parse(raw);
      if (!d || typeof d !== 'object') throw new Error('bad shape');
      return normalize(d);
    } catch (e) {
      // 解析失败：备份原始串再重来，绝不直接抹掉用户数据
      try { window.localStorage.setItem(STORE_KEY + '.broken', raw); } catch (_) {}
      return fresh();
    }
  }

  function save() {
    try { window.localStorage.setItem(STORE_KEY, JSON.stringify(state)); }
    catch (e) { storageWorks = false; toast('保存失败，设备存储可能已满'); }
    renderNote();
  }

  function fresh() { return { v: 1, items: {} }; }

  /** 归一化：修坏字段，但保留不认识的字段（向后兼容） */
  function normalize(raw) {
    var s = {}, k;
    for (k in raw) { if (Object.prototype.hasOwnProperty.call(raw, k)) s[k] = raw[k]; }
    s.v = 1;
    s.items = (raw.items && typeof raw.items === 'object') ? raw.items : {};
    return s;
  }

  /* ---------- 状态 ---------- */
  var state = load();
  var today = todayKey();

  /* ---------- DOM ---------- */
  var $ = function (id) { return document.getElementById(id); };
  var elOut = $('output'), elNote = $('note'), elToast = $('toast');

  /* ---------- Toast（不用 alert：它可用，但会打断操作） ---------- */
  var toastTimer = null;
  function toast(msg) {
    elToast.textContent = msg;
    elToast.hidden = false;
    void elToast.offsetWidth;               // 强制重排，保证过渡能跑
    elToast.classList.add('is-open');
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      elToast.classList.remove('is-open');
      toastTimer = setTimeout(function () { elToast.hidden = true; }, 240);
    }, 1900);
  }

  /* ---------- 渲染 ---------- */
  function render() {
    var n = Object.keys(state.items).length;
    var d = dateOf(today);
    elOut.textContent = n
      ? ('已记录 ' + n + ' 天，最近一次：' + (d.getMonth() + 1) + '月' + d.getDate() + '日')
      : '还没有记录';
    renderNote();
  }

  function renderNote() {
    // 容器禁用了申请持久化的 API，也没有任何导出手段，必须如实告知
    elNote.textContent = storageWorks
      ? '记录只存在这台手机上'
      : '当前无法保存记录：设备存储不可用';
  }

  /* ---------- 交互 ---------- */
  $('btnAct').addEventListener('click', function () {
    ensureToday();                          // 万一正好跨过 0 点，先纠正
    state.items[today] = 1;
    save();
    render();
    toast('已记录');
  });

  /* ---------- 跨午夜：两种情况都要覆盖 ---------- */
  function ensureToday() {
    var k = todayKey();
    if (k === today) return false;
    today = k;
    render();
    return true;
  }
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') ensureToday();
  });
  // 页面一直亮着跨过 0 点时不会触发 visibilitychange，靠轮询兜底
  setInterval(function () {
    if (document.visibilityState === 'visible') ensureToday();
  }, 30000);

  /* ---------- 启动 ---------- */
  render();
})();
