use feedback_receiver::{serve, Config};
use tokio::net::TcpListener;
use tokio::signal::unix::{signal, SignalKind};

#[tokio::main]
async fn main() {
    let config = match Config::from_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("feedback-receiver: {e}");
            std::process::exit(2);
        }
    };
    let listener = match TcpListener::bind(config.listen).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("feedback-receiver: cannot listen on {}: {e}", config.listen);
            std::process::exit(1);
        }
    };
    println!(
        "feedback-receiver listening on {}, filing to {}",
        config.listen, config.repo
    );
    let mut term = signal(SignalKind::terminate()).expect("signal handler");
    let shutdown = async move {
        tokio::select! {
            _ = term.recv() => {},
            _ = tokio::signal::ctrl_c() => {},
        }
    };
    serve(listener, config, shutdown).await;
}
