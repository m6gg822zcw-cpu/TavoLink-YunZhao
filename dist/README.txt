这个目录不提交 APK/IPA 占位文件。
.github/workflows/release-mobile.yml 会生成真实 APK、unsigned IPA、可选 signed IPA 与 SHA-256，并上传到 Actions Artifacts；v* Tag 构建还会附加到 GitHub Release。
