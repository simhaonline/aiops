import { NextResponse } from "next/server";
export const dynamic="force-dynamic";
export async function GET(){try{const response=await fetch(`${process.env.AIOPS_API_URL??"http://127.0.0.1:11081"}/api/workspace/capabilities`,{cache:"no-store",signal:AbortSignal.timeout(2500)});if(!response.ok)throw new Error("api unavailable");return NextResponse.json(await response.json());}catch{return NextResponse.json({modalities:[],surfaces:[],registry:{types:[],states:[]},routing:{},safety:{}},{status:503});}}
