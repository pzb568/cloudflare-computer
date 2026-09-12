import { DurableObject } from "cloudflare:workers";
import {
  withWorkspace,
  getWorkspace,
} from "@cloudflare/computer";
import {
  WorkerShellBackend,
} from "@cloudflare/computer/backends/worker-shell";

export class Agent extends withWorkspace(
  class extends DurableObject<Env> {},
  (self) => ({
    storage: self.ctx.storage,
    backends: [
      new WorkerShellBackend({
        loader: self.env.LOADER,
        workspace: {
          binding: "Agent",
          id: self.ctx.id.toString(),
        },
        ctx: self.ctx,
      }),
    ],
  }),
) {}

export default {
  async fetch(
    request: Request,
    env: Env,
  ): Promise<Response> {
    const url = new URL(request.url);

    const id = env.Agent.idFromName("demo");
    const agent = env.Agent.get(id);

    using ws = await getWorkspace(agent);

    // GET /
    if (request.method === "GET" && url.pathname === "/") {
      return Response.json({
        ok: true,
        name: "cloudflare-computer",
        version: "0.3.0",
        backend: "worker-shell",
      });
    }

    // PUT /file
    if (request.method === "PUT" && url.pathname === "/file") {
      const path =
        url.searchParams.get("path") || "/hello.txt";

      const body = await request.text();

      await ws.fs.writeFile(path, body);

      return Response.json({
        ok: true,
        path,
      });
    }

    // GET /file
    if (request.method === "GET" && url.pathname === "/file") {
      const path =
        url.searchParams.get("path") || "/hello.txt";

      const content = await ws.fs.readFile(
        path,
        "utf8",
      );

      return new Response(content, {
        headers: {
          "content-type": "text/plain; charset=utf-8",
        },
      });
    }

    // POST /exec
    if (
      request.method === "POST" &&
      url.pathname === "/exec"
    ) {
      const body = await request.json<{
        command?: string;
      }>();

      if (!body.command) {
        return Response.json(
          {
            ok: false,
            error: "command is required",
          },
          { status: 400 },
        );
      }

      using run = await ws.runtime.exec(
        body.command,
      );

      const result = await run.result();

      return Response.json({
        ok: true,
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
      });
    }

    return new Response("Not Found", {
      status: 404,
    });
  },
} satisfies ExportedHandler<Env>;
