import { Injectable } from "@nestjs/common";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand, HeadObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { join, resolve } from "node:path";

export type StoredObject = { key: string; size: number; contentType: string; etag?: string };

@Injectable()
export class StorageService {
  private readonly mode = process.env.AIOPS_STORAGE_MODE ?? (process.env.AIOPS_OBJECT_STORAGE_BUCKET ? "s3" : "filesystem");
  private readonly bucket = process.env.AIOPS_OBJECT_STORAGE_BUCKET ?? "";
  private readonly root = resolve(process.env.AIOPS_STORAGE_ROOT ?? "/tmp/aiops-object-storage");
  private readonly client = this.mode === "s3" ? new S3Client({ region: process.env.AIOPS_OBJECT_STORAGE_REGION ?? "us-east-1", endpoint: process.env.AIOPS_OBJECT_STORAGE_ENDPOINT || undefined, forcePathStyle: process.env.AIOPS_OBJECT_STORAGE_FORCE_PATH_STYLE === "true", credentials: process.env.AIOPS_OBJECT_STORAGE_ACCESS_KEY && process.env.AIOPS_OBJECT_STORAGE_SECRET_KEY ? { accessKeyId: process.env.AIOPS_OBJECT_STORAGE_ACCESS_KEY, secretAccessKey: process.env.AIOPS_OBJECT_STORAGE_SECRET_KEY } : undefined }) : undefined;

  validateKey(key:string) { if (!key || key.startsWith("/") || key.includes("..") || !/^[A-Za-z0-9][A-Za-z0-9._\/-]{0,500}$/.test(key)) throw new Error("Invalid storage key."); return key; }
  async put(key:string, body:Buffer, contentType:string, metadata:Record<string,string>={}) : Promise<StoredObject> { this.validateKey(key); if (body.length > Number(process.env.AIOPS_MAX_UPLOAD_BYTES ?? 26214400)) throw new Error("Object exceeds the configured upload limit."); if (this.mode === "s3") { if (!this.client || !this.bucket) throw new Error("Object storage is not configured."); const response=await this.client.send(new PutObjectCommand({Bucket:this.bucket,Key:key,Body:body,ContentType:contentType,ContentLength:body.length,Metadata:metadata})); return {key,size:body.length,contentType,etag:response.ETag}; } const path=join(this.root,key); await mkdir(join(path,".."),{recursive:true,mode:0o700}); await writeFile(path,body,{mode:0o600}); return {key,size:body.length,contentType,etag:createHash("sha256").update(body).digest("hex")}; }
  async get(key:string):Promise<Buffer>{this.validateKey(key);if(this.mode === "s3"){if(!this.client||!this.bucket)throw new Error("Object storage is not configured.");const result=await this.client.send(new GetObjectCommand({Bucket:this.bucket,Key:key}));return Buffer.from(await result.Body!.transformToByteArray());}return readFile(join(this.root,key));}
  async exists(key:string){try{if(this.mode === "s3"){if(!this.client||!this.bucket)throw new Error("Object storage is not configured.");await this.client.send(new HeadObjectCommand({Bucket:this.bucket,Key:key}));}else await readFile(join(this.root,this.validateKey(key)));return true;}catch{return false;}}
  async remove(key:string){this.validateKey(key);if(this.mode === "s3"){if(!this.client||!this.bucket)throw new Error("Object storage is not configured.");await this.client.send(new DeleteObjectCommand({Bucket:this.bucket,Key:key}));}else await unlink(join(this.root,key)).catch(()=>undefined);}
  async signedDownload(key:string, expiresIn=Number(process.env.AIOPS_SIGNED_URL_SECONDS ?? 300)){this.validateKey(key);if(this.mode !== "s3") throw new Error("Signed URLs require S3-compatible storage; configure AIOPS_STORAGE_MODE=s3.");if(!this.client||!this.bucket)throw new Error("Object storage is not configured.");return getSignedUrl(this.client,new GetObjectCommand({Bucket:this.bucket,Key:key}),{expiresIn:Math.min(Math.max(expiresIn,30),3600)});}
}
