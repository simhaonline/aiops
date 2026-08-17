import { NextResponse } from "next/server";
export const dynamic="force-dynamic";
export async function GET(){try{const response=await fetch(`${process.env.AIOPS_API_URL??"http://127.0.0.1:11081"}/api/overview`,{cache:"no-store",signal:AbortSignal.timeout(2500)});if(!response.ok)throw new Error("api unavailable");return NextResponse.json(await response.json());}catch{return NextResponse.json({host:"unavailable",uptime:"—",load:0,memory:0,managers:[],projects:[]},{status:503});}}
