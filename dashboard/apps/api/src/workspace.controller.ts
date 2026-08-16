import { Controller, Get } from "@nestjs/common";

const modalities=[
  {id:"text",label:"Text",accept:["text/plain","text/markdown"],actions:["chat","summarize","rewrite","extract"]},
  {id:"code",label:"Codebase",accept:["text/*","application/json","application/zip"],actions:["explain","review","debug","refactor","test"]},
  {id:"document",label:"Documents",accept:["application/pdf","text/csv","application/json","application/vnd.openxmlformats-officedocument.wordprocessingml.document"],actions:["extract","compare","question-answer","translate"]},
  {id:"image",label:"Image",accept:["image/png","image/jpeg","image/webp","image/gif"],actions:["understand","ocr","generate","edit"]},
  {id:"video",label:"Video",accept:["video/mp4","video/webm","video/quicktime"],actions:["transcribe","summarize","chapter","understand"]},
  {id:"voice",label:"Voice",accept:["audio/mpeg","audio/wav","audio/ogg","audio/webm"],actions:["transcribe","translate","synthesize","conversation"]},
  {id:"translation",label:"Translation",accept:["text/*","application/pdf","audio/*","video/*"],actions:["detect","translate","localize","subtitle"]},
];

@Controller("workspace")
export class WorkspaceController {
  @Get("capabilities") capabilities(){return {
    product:"SIMHA AiOps Studio",version:"1.0.0",modalities,
    surfaces:["studio","codebases","knowledge","media","workflows","registry","projects","operations"],
    registry:{types:["skill","agent","mcp","plugin"],states:["discovered","quarantined","scanned","reviewed","approved","published","rejected","revoked"],autoInstall:false},
    routing:{gateway:"LiteLLM",policy:"capability-aware",costPolicy:"verified-free-first",fallback:"explicit-only"},
    safety:{uploads:"quarantine-first",publicArtifacts:"manual-approval",secrets:"server-side-only",mutations:"broker-allowlist"}
  };}
}
