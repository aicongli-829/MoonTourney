///|
/// Node adapters contain no tournament decisions. Reads and writes return envelopes.
extern "js" fn read_file(path : String) -> String =
  #|(path) => { try { const fs=process.getBuiltinModule("fs"); const size=fs.statSync(path).size; if(size>4000000) throw Error("File exceeds 4 MB"); return JSON.stringify({ok:true,content:fs.readFileSync(path,"utf8").replace(/^\uFEFF/,"")}); } catch(e) {return JSON.stringify({ok:false,error:e.message});} }

///|
/// Refuse to overwrite any existing file. The CLI always writes a new snapshot.
extern "js" fn write_file(path : String, content : String) -> String =
  #|(path,content) => { try {process.getBuiltinModule("fs").writeFileSync(path,content,{encoding:"utf8",flag:"wx"});return JSON.stringify({ok:true});} catch(e) {return JSON.stringify({ok:false,error:e.message});} }

///|
extern "js" fn fail(message : String) -> Unit =
  #|(message) => {console.error(message);process.exitCode=1;}
