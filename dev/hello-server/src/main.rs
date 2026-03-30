use axum::{response::Html, routing::get, Router};
use leptos::prelude::*;
use std::env;
use std::net::SocketAddr;

#[component]
fn App(env_name: String) -> impl IntoView {
    view! {
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                <title>"Hello from " {env_name.clone()}</title>
                <style>
                    "
                    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                        background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
                        color: #e2e8f0;
                    }
                    .card {
                        text-align: center;
                        padding: 3rem 4rem;
                        border-radius: 1rem;
                        background: rgba(255, 255, 255, 0.05);
                        backdrop-filter: blur(12px);
                        border: 1px solid rgba(255, 255, 255, 0.1);
                        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                    }
                    h1 { font-size: 2.5rem; font-weight: 700; margin-bottom: 0.5rem; }
                    .env-badge {
                        display: inline-block;
                        margin-top: 1rem;
                        padding: 0.4rem 1.2rem;
                        border-radius: 9999px;
                        font-size: 0.875rem;
                        font-weight: 600;
                        text-transform: uppercase;
                        letter-spacing: 0.05em;
                        background: rgba(99, 102, 241, 0.2);
                        border: 1px solid rgba(99, 102, 241, 0.4);
                        color: #a5b4fc;
                    }
                    .meta {
                        margin-top: 1.5rem;
                        font-size: 0.8rem;
                        color: #64748b;
                    }
                    "
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>"Hello from the " <span style="color: #818cf8;">{env_name.clone()}</span></h1>
                    <div class="env-badge">{env_name.clone()}</div>
                    <p class="meta">"Axum + Leptos \u{2022} Jetson Orin Nano"</p>
                </div>
            </body>
        </html>
    }
}

async fn index() -> Html<String> {
    let env_name = env::var("APP_ENV").unwrap_or_else(|_| "unknown".to_string());
    let html = leptos::ssr::render_to_string(move || {
        view! { <App env_name=env_name.clone() /> }
    });
    Html(html.to_string())
}

async fn health() -> &'static str {
    "ok"
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let host = env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse()
        .expect("PORT must be a valid u16");

    let app = Router::new()
        .route("/", get(index))
        .route("/health", get(health));

    let addr: SocketAddr = format!("{host}:{port}")
        .parse()
        .expect("Invalid HOST:PORT");

    println!("Server running on http://{addr}");
    println!("Environment: {}", env::var("APP_ENV").unwrap_or_else(|_| "unknown".to_string()));

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
