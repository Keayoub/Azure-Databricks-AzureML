"""
Sample training script for AzureML SDK v2 integration.

This script demonstrates a basic training workflow that can be submitted
from Databricks to Azure Machine Learning.
"""

import argparse
import os
from pathlib import Path

# This would typically import your ML libraries
# import pandas as pd
# import numpy as np
# from sklearn.ensemble import RandomForestClassifier
# from sklearn.model_selection import train_test_split
# from sklearn.metrics import accuracy_score, precision_score, recall_score
import mlflow


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Train a machine learning model")
    parser.add_argument(
        "--learning_rate",
        type=float,
        default=0.01,
        help="Learning rate for training"
    )
    parser.add_argument(
        "--batch_size",
        type=int,
        default=32,
        help="Batch size for training"
    )
    parser.add_argument(
        "--epochs",
        type=int,
        default=10,
        help="Number of training epochs"
    )
    parser.add_argument(
        "--data_path",
        type=str,
        default="./data",
        help="Path to training data"
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="./outputs",
        help="Directory to save model outputs"
    )
    return parser.parse_args()


def load_data(data_path):
    """
    Load and prepare training data.
    
    Args:
        data_path: Path to the data directory
        
    Returns:
        X_train, X_test, y_train, y_test: Training and test datasets
    """
    print(f"Loading data from {data_path}")
    
    # Example: Load your data here
    # data = pd.read_csv(f"{data_path}/train.csv")
    # X = data.drop('target', axis=1)
    # y = data['target']
    # X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    
    # For demonstration purposes
    print("Data loaded successfully")
    return None, None, None, None


def train_model(X_train, y_train, learning_rate, batch_size, epochs):
    """
    Train the machine learning model.
    
    Args:
        X_train: Training features
        y_train: Training labels
        learning_rate: Learning rate hyperparameter
        batch_size: Batch size for training
        epochs: Number of training epochs
        
    Returns:
        model: Trained model
    """
    print(f"Training model with lr={learning_rate}, batch_size={batch_size}, epochs={epochs}")
    
    # Example: Train your model here
    # model = RandomForestClassifier(n_estimators=100, random_state=42)
    # model.fit(X_train, y_train)
    
    # For demonstration purposes
    print("Model training completed")
    return None


def evaluate_model(model, X_test, y_test):
    """
    Evaluate the trained model.
    
    Args:
        model: Trained model
        X_test: Test features
        y_test: Test labels
        
    Returns:
        metrics: Dictionary of evaluation metrics
    """
    print("Evaluating model on test set")
    
    # Example: Evaluate your model here
    # y_pred = model.predict(X_test)
    # accuracy = accuracy_score(y_test, y_pred)
    # precision = precision_score(y_test, y_pred, average='weighted')
    # recall = recall_score(y_test, y_pred, average='weighted')
    
    # PLACEHOLDER VALUES - Replace with actual model evaluation in production
    # These are demonstration values only and not from real model training
    metrics = {
        'accuracy': 0.95,  # Example value
        'precision': 0.93,  # Example value
        'recall': 0.92,  # Example value
        'f1_score': 0.925  # Example value
    }
    
    print(f"Model evaluation completed: {metrics}")
    return metrics


def save_model(model, output_dir):
    """
    Save the trained model.
    
    Args:
        model: Trained model to save
        output_dir: Directory to save the model
    """
    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "model.pkl")
    
    # Example: Save your model here
    # import joblib
    # joblib.dump(model, model_path)
    
    print(f"Model saved to {model_path}")
    return model_path


def main():
    """Main training workflow."""
    # Parse arguments
    args = parse_args()
    
    # Start MLflow run for experiment tracking
    mlflow.start_run()
    
    # Log parameters
    mlflow.log_param("learning_rate", args.learning_rate)
    mlflow.log_param("batch_size", args.batch_size)
    mlflow.log_param("epochs", args.epochs)
    
    # Load data
    X_train, X_test, y_train, y_test = load_data(args.data_path)
    
    # Train model
    model = train_model(
        X_train, y_train,
        args.learning_rate,
        args.batch_size,
        args.epochs
    )
    
    # Evaluate model
    metrics = evaluate_model(model, X_test, y_test)
    
    # Log metrics to MLflow
    for metric_name, metric_value in metrics.items():
        mlflow.log_metric(metric_name, metric_value)
    
    # Save model
    model_path = save_model(model, args.output_dir)
    
    # Log model to MLflow
    # mlflow.sklearn.log_model(model, "model")
    
    print("\n✅ Training completed successfully!")
    print(f"   Accuracy: {metrics['accuracy']:.4f}")
    print(f"   Precision: {metrics['precision']:.4f}")
    print(f"   Recall: {metrics['recall']:.4f}")
    print(f"   F1 Score: {metrics['f1_score']:.4f}")
    
    mlflow.end_run()


if __name__ == "__main__":
    main()
