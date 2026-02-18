"""
Example training script for AzureML Command Jobs.

This script demonstrates a simple training workflow that can be submitted
from Databricks to AzureML using the command() API.

Usage:
    python train.py --n-estimators 100 --test-size 0.2
"""

import argparse
import os
from datetime import datetime

# Azure ML imports
import mlflow
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Train a simple classifier")
    
    parser.add_argument(
        "--n-estimators",
        type=int,
        default=100,
        help="Number of trees in the random forest"
    )
    
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Proportion of dataset to use for testing"
    )
    
    parser.add_argument(
        "--random-state",
        type=int,
        default=42,
        help="Random state for reproducibility"
    )
    
    return parser.parse_args()


def load_data(test_size=0.2, random_state=42):
    """
    Load and split the Iris dataset.
    
    Args:
        test_size: Proportion of dataset to use for testing
        random_state: Random state for reproducibility
        
    Returns:
        Tuple of (X_train, X_test, y_train, y_test)
    """
    print("Loading dataset...")
    iris = load_iris()
    
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data,
        iris.target,
        test_size=test_size,
        random_state=random_state
    )
    
    print(f"  Training samples: {len(X_train)}")
    print(f"  Test samples: {len(X_test)}")
    
    return X_train, X_test, y_train, y_test


def train_model(X_train, y_train, n_estimators=100, random_state=42):
    """
    Train a Random Forest classifier.
    
    Args:
        X_train: Training features
        y_train: Training labels
        n_estimators: Number of trees in the forest
        random_state: Random state for reproducibility
        
    Returns:
        Trained model
    """
    print("\nTraining model...")
    print(f"  Algorithm: Random Forest")
    print(f"  Number of estimators: {n_estimators}")
    
    model = RandomForestClassifier(
        n_estimators=n_estimators,
        random_state=random_state
    )
    
    model.fit(X_train, y_train)
    
    print("  ✓ Training complete")
    
    return model


def evaluate_model(model, X_test, y_test):
    """
    Evaluate the trained model on test data.
    
    Args:
        model: Trained model
        X_test: Test features
        y_test: Test labels
        
    Returns:
        Dictionary of metrics
    """
    print("\nEvaluating model...")
    
    y_pred = model.predict(X_test)
    
    metrics = {
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred, average='weighted'),
        "recall": recall_score(y_test, y_pred, average='weighted'),
        "f1_score": f1_score(y_test, y_pred, average='weighted')
    }
    
    print("  Metrics:")
    for metric_name, value in metrics.items():
        print(f"    {metric_name}: {value:.4f}")
    
    return metrics


def main():
    """Main training workflow."""
    print("=" * 80)
    print("TRAINING JOB - Submitted from Databricks to AzureML")
    print("=" * 80)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Parse arguments
    args = parse_args()
    
    print("\nConfiguration:")
    print(f"  N Estimators: {args.n_estimators}")
    print(f"  Test Size: {args.test_size}")
    print(f"  Random State: {args.random_state}")
    
    # Start MLflow run
    mlflow.start_run()
    
    try:
        # Log parameters
        mlflow.log_params({
            "n_estimators": args.n_estimators,
            "test_size": args.test_size,
            "random_state": args.random_state,
            "algorithm": "random_forest",
            "source": "databricks"
        })
        
        # Load data
        X_train, X_test, y_train, y_test = load_data(
            test_size=args.test_size,
            random_state=args.random_state
        )
        
        # Train model
        model = train_model(
            X_train, y_train,
            n_estimators=args.n_estimators,
            random_state=args.random_state
        )
        
        # Evaluate model
        metrics = evaluate_model(model, X_test, y_test)
        
        # Log metrics to MLflow
        mlflow.log_metrics(metrics)
        
        # Log model
        mlflow.sklearn.log_model(model, "model")
        
        # Save model to outputs directory (AzureML will upload this)
        output_dir = "./outputs"
        os.makedirs(output_dir, exist_ok=True)
        
        import joblib
        model_path = os.path.join(output_dir, "model.pkl")
        joblib.dump(model, model_path)
        print(f"\n✓ Model saved to: {model_path}")
        
        print("\n" + "=" * 80)
        print("✓ TRAINING COMPLETE")
        print("=" * 80)
        print(f"Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Final Accuracy: {metrics['accuracy']:.4f}")
        
    except Exception as e:
        print(f"\n✗ Training failed: {e}")
        raise
    
    finally:
        mlflow.end_run()


if __name__ == "__main__":
    main()
