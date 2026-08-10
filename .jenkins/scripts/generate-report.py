#!/usr/bin/env python3
import json
import os
import sys
import glob
import xml.etree.ElementTree as ET
from datetime import datetime

def generate_report():
    report_lines = []
    
    # Header
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    target_services = os.environ.get("CHANGED_SERVICES", "N/A")
    branch = os.environ.get("BRANCH_NAME", os.environ.get("GIT_BRANCH", "N/A"))
    build_number = os.environ.get("BUILD_NUMBER", "N/A")
    
    report_lines.append("# 📋 BÁO CÁO TỔNG HỢP CHẤT LƯỢNG & BẢO MẬT CI/CD")
    report_lines.append(f"**Thời gian tạo:** `{now}` | **Build #:** `{build_number}` | **Nhánh:** `{branch}`")
    report_lines.append(f"**Dịch vụ mục tiêu:** `{target_services}`\n")
    report_lines.append("---\n")
    
    # 1. GITLEAKS SUMMARY
    report_lines.append("## 🔑 1. Quét Lộ Lọt Thông Tin Nhạy Cảm (Gitleaks)")
    gitleaks_file = "gitleaks-report.json"
    if os.path.exists(gitleaks_file):
        try:
            with open(gitleaks_file, "r", encoding="utf-8") as f:
                content = f.read().strip()
                if content:
                    leaks = json.loads(content)
                    if leaks:
                        report_lines.append(f"⚠️ **Phát hiện {len(leaks)} vị trí nghi ngờ lộ secret/key!**\n")
                        report_lines.append("| Loại Secret | File | Dòng | Đoạn Mã / Gợi ý |")
                        report_lines.append("| :--- | :--- | :--- | :--- |")
                        for leak in leaks[:10]: # Top 10
                            rule = leak.get("Description", leak.get("RuleID", "Unknown"))
                            file_path = leak.get("File", "N/A")
                            line = leak.get("StartLine", "N/A")
                            match = leak.get("Match", "******")[:30] + "..."
                            report_lines.append(f"| {rule} | `{file_path}` | `{line}` | `{match}` |")
                    else:
                        report_lines.append("✅ **An toàn:** Không tìm thấy secret hay key nhạy cảm nào bị lộ.")
                else:
                    report_lines.append("✅ **An toàn:** Không phát hiện secret nào bị lộ.")
        except Exception as e:
            report_lines.append(f"⚠️ Đã quét xong (không tìm thấy secret lộ hoặc lỗi đọc file report: {e})")
    else:
        report_lines.append("ℹ️ Không tìm thấy file báo cáo Gitleaks.")
    report_lines.append("\n")

    # 2. SONARCLOUD SUMMARY
    report_lines.append("## 📊 2. Phân Tích Chất Lượng Mã Nguồn (SonarCloud)")
    sonar_org = "thanhdu14"
    sonar_project = "ThanhDu14_yas-devops-projects"
    sonar_url = f"https://sonarcloud.io/dashboard?id={sonar_project}"
    report_lines.append(f"- **Dự án trên SonarCloud:** [{sonar_project}]({sonar_url})")
    report_lines.append(f"- **Tổ chức (Organization):** `{sonar_org}`")
    report_lines.append("- **Hạng mục được kiểm tra:**")
    report_lines.append("  - 🐛 **Bugs & Độ tin cậy (Reliability):** Lỗi logic có thể gây crash ứng dụng.")
    report_lines.append("  - 🛡️ **Lỗ hổng bảo mật (Vulnerabilities):** Lỗi code theo tiêu chuẩn bảo mật OWASP.")
    report_lines.append("  - 🧹 **Tính bảo trì (Maintainability / Code Smells):** Code dư thừa, trùng lặp cần dọn dẹp.")
    report_lines.append("  - 📈 **Độ bao phủ kiểm thử (Coverage):** Dựa trên kết quả JaCoCo của Unit Test.")
    report_lines.append(f"👉 **Xem chi tiết từng dòng code vi phạm tại:** [SonarCloud Dashboard]({sonar_url})\n")

    # 3. TRIVY SUMMARY
    report_lines.append("## 🛡️ 3. Quét Lỗ Hổng Thư Viện & Phụ Thuộc (Trivy)")
    trivy_file = "trivy-report.json"
    if os.path.exists(trivy_file):
        try:
            with open(trivy_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                results = data.get("Results", [])
                total_vulns = []
                for res in results:
                    target = res.get("Target", "N/A")
                    for v in res.get("Vulnerabilities", []):
                        v["TargetFile"] = target
                        total_vulns.append(v)
                
                if total_vulns:
                    report_lines.append(f"⚠️ **Tìm thấy {len(total_vulns)} lỗ hổng bảo mật (Mức độ HIGH/CRITICAL):**\n")
                    report_lines.append("| Mã CVE | Mức độ | Gói Thư Viện | Phiên Bản Hiện Tại | Phiên Bản Đã Fix | File / Target |")
                    report_lines.append("| :--- | :--- | :--- | :--- | :--- | :--- |")
                    for vuln in total_vulns[:15]: # Top 15
                        cve = vuln.get("VulnerabilityID", "N/A")
                        sev = vuln.get("Severity", "N/A")
                        pkg = vuln.get("PkgName", "N/A")
                        installed = vuln.get("InstalledVersion", "N/A")
                        fixed = vuln.get("FixedVersion", "Chưa có bản fix")
                        target_file = vuln.get("TargetFile", "N/A")
                        report_lines.append(f"| [{cve}](https://nvd.nist.gov/vuln/detail/{cve}) | **{sev}** | `{pkg}` | `{installed}` | `{fixed}` | `{target_file}` |")
                    if len(total_vulns) > 15:
                        report_lines.append(f"\n*(...và {len(total_vulns) - 15} lỗ hổng khác, xem chi tiết trong file trivy-report.json)*")
                else:
                    report_lines.append("✅ **Tuyệt vời:** Không phát hiện lỗ hổng nghiêm trọng (HIGH/CRITICAL) nào trong các thư viện phụ thuộc.")
        except Exception as e:
            report_lines.append(f"⚠️ Báo cáo Trivy: Đã quét xong (Lỗi parse file json: {e})")
    else:
        report_lines.append("ℹ️ Không tìm thấy file báo cáo Trivy.")
    report_lines.append("\n")

    # 4. UNIT TEST (JUNIT) SUMMARY
    report_lines.append("## 🧪 4. Kết Quả Kiểm Thử (Unit Tests - JUnit)")
    test_reports = glob.glob("**/target/surefire-reports/TEST-*.xml", recursive=True)
    total_tests = 0
    total_failures = 0
    total_errors = 0
    total_skipped = 0
    
    for report in test_reports:
        try:
            tree = ET.parse(report)
            root = tree.getroot()
            total_tests += int(root.attrib.get("tests", 0))
            total_failures += int(root.attrib.get("failures", 0))
            total_errors += int(root.attrib.get("errors", 0))
            total_skipped += int(root.attrib.get("skipped", 0))
        except Exception:
            pass
            
    if total_tests > 0:
        passed = total_tests - total_failures - total_errors - total_skipped
        report_lines.append(f"- **Tổng số bài test đã chạy:** `{total_tests}`")
        report_lines.append(f"- **Thành công (Passed):** `✅ {passed}`")
        report_lines.append(f"- **Thất bại (Failures):** `❌ {total_failures}`")
        report_lines.append(f"- **Lỗi phát sinh (Errors):** `⚠️ {total_errors}`")
        report_lines.append(f"- **Bỏ qua (Skipped):** `⏭️ {total_skipped}`")
    else:
        report_lines.append("ℹ️ Không có bài Unit Test nào được chạy hoặc các bài test đã được cấu hình skip.")
    
    report_lines.append("\n---\n*Báo cáo được tạo tự động bởi Jenkins Pipeline.*")

    with open("BAO_CAO_CI.md", "w", encoding="utf-8") as out:
        out.write("\n".join(report_lines))
    print("Đã tạo thành công file BAO_CAO_CI.md")

if __name__ == "__main__":
    generate_report()
