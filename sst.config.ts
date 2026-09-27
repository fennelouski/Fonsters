/// <reference path="./.sst/platform/config.d.ts" />
export default $config({
  app(input) {
    if (input.stage !== "parallel") throw new Error("Only the parallel test stage is enabled.");
    return { name: "fonstersflags", home: "aws", removal: "retain", protect: true,
      providers: { aws: { region: "us-west-2", allowedAccountIds: ["074861507225"] } } };
  },
  async run() {
    const { previewRequest, previewResponse } = await import("./scripts/aws-preview.mjs");
    const password = new sst.Secret("PreviewPassword");
    const router = new sst.aws.Router("Router", {
      protection: "oac",
      edge: {
        viewerRequest: { injection: password.value.apply(previewRequest) },
        viewerResponse: { injection: previewResponse },
      },
    });
    const api = new sst.aws.Function("Flags", {
      handler: "aws/flags.handler",
      runtime: "nodejs24.x",
      memory: "128 MB",
      timeout: "10 seconds",
      copyFiles: [{ from: "config/flags.json", to: "config/flags.json" }],
      url: { router: { instance: router }, cors: false },
    });
    return { url: api.url };
  },
});
