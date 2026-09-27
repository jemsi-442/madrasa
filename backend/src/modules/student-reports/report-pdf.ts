import PDFDocument from "pdfkit";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { schoolDate } from "../attendance/register.service";
import type { LearningReport } from "./student-reports.service";

export function reportPdf(snapshot: LearningReport, reference: string, publishedAt?: Date): Promise<Buffer> {
  return new Promise((resolvePdf, reject) => {
    // Resolve both source and compiled layouts; fonts ship with the backend.
    const fonts = [resolve(__dirname, "../../../assets/fonts"), resolve(__dirname, "../../../../assets/fonts")]
      .find(p => existsSync(resolve(p, "DejaVuSans.ttf")));
    if (!fonts) return reject(new Error("Report fonts are missing from the deployment"));
    const doc = new PDFDocument({ size: "A4", margin: 48, bufferPages: true,
      info: { Title: `${snapshot.period.name} - ${snapshot.student.fullName}`, Author: snapshot.school,
        CreationDate: publishedAt ?? new Date() } });
    const chunks: Buffer[] = [];
    doc.on("data", c => chunks.push(c));
    doc.on("error", reject);
    doc.on("end", () => resolvePdf(Buffer.concat(chunks)));
    doc.registerFont("body", resolve(fonts, "DejaVuSans.ttf"));
    doc.registerFont("heading", resolve(fonts, "DejaVuSans-Bold.ttf"));
    const heading = (text: string) => { if (doc.y > 700) doc.addPage(); doc.moveDown().font("heading").fontSize(12).fillColor("#142a40").text(text).moveDown(0.4); };
    const line = (text: string) => doc.font("body").fontSize(10).fillColor("#34485d").text(text, { paragraphGap: 6 });
    doc.font("heading").fontSize(20).fillColor("#142a40").text(snapshot.school);
    doc.fontSize(15).fillColor("#a7852e").text("Student Learning Report").moveDown();
    line(`${publishedAt ? "Published" : "DRAFT - Not published"} | Reference ${reference}`);
    if (publishedAt) line(`Issued: ${schoolDate(publishedAt)}`);
    line(`${snapshot.period.name} | ${snapshot.period.startsOn} to ${snapshot.period.endsOn}`);
    heading(snapshot.student.fullName);
    line(`${snapshot.student.admissionNo} | ${snapshot.className}`);
    line(`Prepared by: ${snapshot.teacher}`);
    heading("Published assessment results");
    if (!snapshot.assessments.length) line("No published assessments recorded in this period.");
    for (const a of snapshot.assessments) {
      line(`${a.subject} - ${a.title} (${a.date}): ${a.score} / ${a.maxScore}`);
      if (a.feedback) line(`Teacher feedback: ${a.feedback}`);
    }
    heading("Attendance");
    const a = snapshot.attendance;
    line(`Present: ${a.present} | Late: ${a.late} | Absent: ${a.absent} | Excused: ${a.excused}`);
    line(`${a.recorded} recorded days. Attendance rate: ${a.rate === null ? "Not available" : `${a.rate}%`}.`);
    heading("Quran learning");
    const q = snapshot.quran;
    line(`${q.sessions} recorded sessions | ${q.memorisedAyahs} unique ayahs recorded as memorised in this period.`);
    line(`Reading sessions: ${q.reading} | Revision: ${q.revision} | Tajweed review: ${q.tajweed}`);
    heading("Teacher feedback"); line(snapshot.feedback || "Not yet provided.");
    heading("How to read this report"); line(snapshot.policy);
    line("This document is a snapshot at publication. Contact the school for corrections or to verify its current publication status.");
    const pages = doc.bufferedPageRange();
    for (let i = pages.start; i < pages.start + pages.count; i++) {
      doc.switchToPage(i);
      doc.font("body").fontSize(8).fillColor("#6d7c8d")
        .text(`${reference} | ${i + 1} / ${pages.count}`, 48, 810, { lineBreak: false });
    }
    doc.end();
  });
}
