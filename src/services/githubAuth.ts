export interface DeviceCodeResponse {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_in: number;
  interval: number;
}

export interface DeviceTokenResponse {
  access_token?: string;
  token_type?: string;
  scope?: string;
  error?: "authorization_pending" | "slow_down" | "expired_token" | "access_denied" | string;
  error_description?: string;
}

const deviceCodeUrl = "https://github.com/login/device/code";
const accessTokenUrl = "https://github.com/login/oauth/access_token";

export async function requestDeviceCode(clientId: string): Promise<DeviceCodeResponse> {
  const response = await fetch(deviceCodeUrl, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      client_id: clientId,
      scope: "read:user"
    })
  });

  if (!response.ok) {
    throw new Error(`GitHub device login failed with HTTP ${response.status}.`);
  }

  return response.json() as Promise<DeviceCodeResponse>;
}

export async function pollForAccessToken(
  clientId: string,
  deviceCode: string
): Promise<DeviceTokenResponse> {
  const response = await fetch(accessTokenUrl, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      client_id: clientId,
      device_code: deviceCode,
      grant_type: "urn:ietf:params:oauth:grant-type:device_code"
    })
  });

  if (!response.ok) {
    throw new Error(`GitHub token polling failed with HTTP ${response.status}.`);
  }

  return response.json() as Promise<DeviceTokenResponse>;
}

export function getStoredToken(): string | null {
  return window.localStorage.getItem("github_access_token");
}

export function storeToken(token: string) {
  window.localStorage.setItem("github_access_token", token);
}

export function clearStoredToken() {
  window.localStorage.removeItem("github_access_token");
}
