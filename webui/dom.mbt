///|
/// Browser plumbing only; event decisions and all rendering live in MoonBit.
extern "js" fn value(id : String) -> String =
  #|(id) => document.getElementById(id)?.value ?? ""

///|
extern "js" fn checked(id : String) -> Bool =
  #|(id) => document.getElementById(id)?.checked === true

///|
extern "js" fn set_value(id : String, text : String) -> Unit =
  #|(id, text) => { const el = document.getElementById(id); if (el) el.value = text; }

///|
extern "js" fn html(id : String, text : String) -> Unit =
  #|(id, text) => { const el = document.getElementById(id); if (el) el.innerHTML = text; }

///|
extern "js" fn text(id : String, content : String) -> Unit =
  #|(id, content) => { const el = document.getElementById(id); if (el) el.textContent = content; }

///|
extern "js" fn hidden(id : String, hide : Bool) -> Unit =
  #|(id, hide) => { const el = document.getElementById(id); if (el) el.hidden = hide; }

///|
extern "js" fn disabled(id : String, off : Bool) -> Unit =
  #|(id, off) => { const el = document.getElementById(id); if (el) el.disabled = off; }

///|
extern "js" fn set_progress(percent : Int) -> Unit =
  #|(percent) => { const fill = document.getElementById("progress-fill"); const track = document.getElementById("progress-track"); if (fill) fill.style.width = percent + "%"; if (track) track.setAttribute("aria-valuenow", String(percent)); }

///|
extern "js" fn scroll_to(id : String) -> Unit =
  #|(id) => document.getElementById(id)?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" })

///|
extern "js" fn selected_tab(name : String) -> Unit =
  #|(name) => { for (const el of document.querySelectorAll("[data-tab]")) { el.setAttribute("aria-selected", String(el.dataset.tab === name)); } }

///|
extern "js" fn bind(id : String, event : String, callback : () -> Unit) -> Unit =
  #|(id, event, cb) => document.getElementById(id)?.addEventListener(event, e => { if (event === "submit") e.preventDefault(); cb(); })

///|
extern "js" fn delegate(
  id : String,
  callback : (String, String) -> Unit,
) -> Unit =
  #|(id, cb) => document.getElementById(id)?.addEventListener("click", e => { const el = e.target.closest("[data-action]"); if (el && document.getElementById(id).contains(el)) cb(el.dataset.action, el.dataset.id ?? ""); })

///|
extern "js" fn get_storage() -> String =
  #|() => { try { return localStorage.getItem("moontourney-session-v1") ?? localStorage.getItem("moonfixture-session-v1") ?? ""; } catch { return ""; } }

///|
extern "js" fn save_storage(content : String) -> Bool =
  #|(content) => { try { localStorage.setItem("moontourney-session-v1", content); return true; } catch { return false; } }

///|
extern "js" fn get_season_storage() -> String =
  #|() => { try { return localStorage.getItem("moontourney-seasons-v1") ?? ""; } catch { return ""; } }

///|
extern "js" fn save_season_storage(content : String) -> Bool =
  #|(content) => { try { localStorage.setItem("moontourney-seasons-v1", content); return true; } catch { return false; } }

///|
extern "js" fn get_active_season_storage() -> String =
  #|() => { try { return localStorage.getItem("moontourney-active-season-v1") ?? ""; } catch { return ""; } }

///|
extern "js" fn save_active_season_storage(key : String) -> Bool =
  #|(key) => { try { localStorage.setItem("moontourney-active-season-v1", key); return true; } catch { return false; } }

///|
extern "js" fn download(name : String, content : String, mime : String) -> Unit =
  #|(name, content, mime) => { const url = URL.createObjectURL(new Blob([content], {type:mime})); const a = document.createElement("a"); a.href=url; a.download=name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }

///|
extern "js" fn load_file(callback : (Bool, String) -> Unit) -> Unit =
  #|(cb) => { const input=document.getElementById("import-file"); const file=input.files?.[0]; input.value=""; if (!file) return; if (file.size>4000000) {cb(false,"File exceeds 4 MB.");return;} file.text().then(s=>cb(true,s.replace(/^\uFEFF/,"")), e=>cb(false,e.message)); }

///|
extern "js" fn open_dialog() -> Unit =
  #|() => document.getElementById("result-dialog").showModal()

///|
extern "js" fn close_dialog() -> Unit =
  #|() => document.getElementById("result-dialog").close()

///|
extern "js" fn confirm_change(message : String) -> Bool =
  #|(message) => window.confirm(message)

///|
extern "js" fn print_page() -> Unit =
  #|() => window.print()

///|
extern "js" fn open_export() -> Unit =
  #|() => document.getElementById("export-dialog").showModal()

///|
extern "js" fn close_export() -> Unit =
  #|() => document.getElementById("export-dialog").close()

///|
extern "js" fn copy_text(content : String, callback : (Bool) -> Unit) -> Unit =
  #|(content, cb) => { if(!navigator.clipboard?.writeText){cb(false);return;} navigator.clipboard.writeText(content).then(()=>cb(true),()=>cb(false)); }
