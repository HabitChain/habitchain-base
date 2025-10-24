import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  devIndicators: false,
  typescript: {
    ignoreBuildErrors: process.env.NEXT_PUBLIC_IGNORE_BUILD_ERROR === "true",
  },
  eslint: {
    ignoreDuringBuilds: process.env.NEXT_PUBLIC_IGNORE_BUILD_ERROR === "true",
  },
  webpack: config => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    config.externals.push("pino-pretty", "lokijs", "encoding");
    return config;
  },
  // Enable standalone output for Docker deployment
  output:
    process.env.NODE_ENV === "production" &&
      !process.env.NEXT_PUBLIC_IPFS_BUILD &&
      !process.env.NEXT_PUBLIC_GITHUB_PAGES &&
      !process.env.CF_PAGES
      ? "standalone"
      : undefined,
};

const isIpfs = process.env.NEXT_PUBLIC_IPFS_BUILD === "true";
const isGitHubPages = process.env.NEXT_PUBLIC_GITHUB_PAGES === "true";

if (isIpfs || isGitHubPages) {
  nextConfig.output = "export";
  nextConfig.trailingSlash = true;
  nextConfig.images = {
    unoptimized: true,
  };
  if (isGitHubPages) {
    nextConfig.basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";
  }
}

module.exports = nextConfig;
