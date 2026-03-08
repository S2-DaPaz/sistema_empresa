import { describe, expect, it } from "vitest";

import { getUserPermissions, hasPermissionFor } from "./permissions";
import { PERMISSIONS } from "../contracts/permissions";

describe("web permission helpers", () => {
  it("falls back to role defaults when role permissions are missing", () => {
    const permissions = getUserPermissions({
      role: "tecnico",
      role_permissions: null,
      permissions: null,
      role_is_admin: false
    });

    expect(permissions).toContain(PERMISSIONS.MANAGE_TASKS);
    expect(permissions).toContain(PERMISSIONS.VIEW_TASKS);
  });

  it("prefers explicit permissions from the authenticated user", () => {
    const permissions = getUserPermissions({
      role: "visitante",
      role_permissions: [],
      permissions: [PERMISSIONS.VIEW_USERS],
      role_is_admin: false
    });

    expect(permissions).toEqual([PERMISSIONS.VIEW_USERS]);
  });

  it("treats manage permission as satisfying the matching view permission", () => {
    const allowed = hasPermissionFor(
      {
        role: "visitante",
        role_permissions: [PERMISSIONS.MANAGE_CLIENTS],
        permissions: [],
        role_is_admin: false
      },
      PERMISSIONS.VIEW_CLIENTS
    );

    expect(allowed).toBe(true);
  });
});
