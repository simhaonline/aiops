import { Injectable } from "@nestjs/common";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const exec = promisify(execFile);
export type RepositoryMetadata = { provider:string; url:string; branch:string; commit?:string; languages:string[] };
export interface RepositoryProvider { supports(provider:string):boolean; validate(url:string):Promise<void>; checkout(url:string, branch:string, signal?:AbortSignal):Promise<{directory:string; metadata:RepositoryMetadata; cleanup:()=>Promise<void>}>; }

@Injectable()
export class GitRepositoryProvider implements RepositoryProvider {
  supports(provider:string){return ["generic","github","gitlab","bitbucket"].includes(provider.toLowerCase());}
  async validate(url:string){if(!/^https:\/\/[^\s]+$/i.test(url))throw new Error("REPOSITORY_URL_INVALID");}
  async checkout(url:string, branch:string){await this.validate(url);const directory=await mkdtemp(join(tmpdir(),"simha-repo-"));try{await exec("git",["clone","--depth","1","--branch",branch,"--no-tags",url,directory],{timeout:120_000,maxBuffer:1024*1024});let commit="";try{commit=(await exec("git",["-C",directory,"rev-parse","HEAD"],{timeout:10_000})).stdout.trim();}catch{}return {directory,metadata:{provider:"git",url,branch,commit,languages:[]},cleanup:()=>rm(directory,{recursive:true,force:true})};}catch(error){await rm(directory,{recursive:true,force:true});const message=error instanceof Error?error.message:"repository checkout failed";throw new Error(message.includes("Authentication")?"REPOSITORY_AUTH_FAILED":"REPOSITORY_CHECKOUT_FAILED");}}
}
export class GitHubRepositoryProvider extends GitRepositoryProvider { supports(provider:string){return provider.toLowerCase()==="github";} }
export class GitLabRepositoryProvider extends GitRepositoryProvider { supports(provider:string){return provider.toLowerCase()==="gitlab";} }
export class BitbucketRepositoryProvider extends GitRepositoryProvider { supports(provider:string){return provider.toLowerCase()==="bitbucket";} }

export interface EmbeddingProvider { embed(texts:string[]):Promise<number[][]>; model:string; dimensions:number; }
@Injectable()
export class EmbeddingProviderService implements EmbeddingProvider {
  model=process.env.AIOPS_EMBEDDING_MODEL ?? "development-deterministic"; dimensions=Number(process.env.AIOPS_EMBEDDING_DIMENSIONS ?? 1536);
  async embed(texts:string[]){if(process.env.AIOPS_EMBEDDINGS_DEV !== "true")throw new Error("EMBEDDING_PROVIDER_NOT_CONFIGURED");return texts.map(text=>{const vector=new Array(this.dimensions).fill(0);for(let i=0;i<text.length;i++)vector[i%this.dimensions]+=text.charCodeAt(i)/255;const norm=Math.sqrt(vector.reduce((sum,value)=>sum+value*value,0))||1;return vector.map(value=>value/norm);});}
}

export interface MediaProvider { submit(kind:string, input:Record<string,unknown>):Promise<{providerJobId:string}>; poll(providerJobId:string):Promise<{status:"running"|"succeeded"|"failed";progress:number;output?:Buffer;contentType?:string;error?:string}>; }
@Injectable()
export class DevelopmentMediaProvider implements MediaProvider {
  async submit(kind:string){if(process.env.AIOPS_MEDIA_DEV !== "true")throw new Error("MEDIA_PROVIDER_NOT_CONFIGURED");return {providerJobId:`dev-${kind}-${Date.now()}`};}
  async poll(providerJobId:string){if(!providerJobId.startsWith("dev-"))return {status:"failed" as const,progress:0,error:"MEDIA_PROVIDER_UNKNOWN_JOB"};return {status:"succeeded" as const,progress:100,output:Buffer.from(`SIMHA development output: ${providerJobId}`),contentType:"text/plain"};}
}
