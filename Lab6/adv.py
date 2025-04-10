import tensorflow as tf
import matplotlib as mpl
import matplotlib.pyplot as plt
import argparse

labrador_retriever_index = 208
panda_index = 388

# Handle command line arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Adversarial Examples", add_help=False)
    parser.add_argument(
        "--image",
        "-i",
        help="Image files, please choose 'panda' or 'labrador'",
        default="panda",
    )
    parser.add_argument(
        "--epsilon",
        "-e",
        type=float,
        help="Epsilon must be between 0 and 1, such as 0.01, 0.05, 0.10, 0.20, etc",
        default=0.0,
    )
    parser.add_argument(
        "--model_version",
        "-v",
        help="Version of the model to use, you can only type in v2-0.5, v2-1.0",
        default="v2-1.0",
    )
    parser.add_argument(
        "--transfer_model_version",
        "-tv",
        help="Version of the transfering model you want to fool. You can only type in v2-0.5, v2-1.0, resnet50, and it should not be the same with the model version you used to generate the adversarial example.",
        default=None,
    )
    parser.add_argument(
        "--target_label",
        "-tl",
        help="For the targeted attack, you can choose a target label you want to construct.",
        type=int,
        default=None,
    )
    parser.add_argument(
        "--print_params",
        "-p",
        help="Print the number of parameters in the model",
        default=False,
        action="store_true",
    )
    parser.add_argument("--help", "-h", help="Show this help message and exit", action="help")
    return parser.parse_args()


# Helper function to preprocess the image so that it can be inputted in MobileNetV2
def preprocess(image_path, model):
    image_raw = tf.io.read_file(image_path)
    image = tf.image.decode_image(image_raw)
    # image = tf.cast(image, tf.float32)
    image = tf.image.resize(image, (224, 224))
    if "v2" in model:
        image = tf.keras.applications.mobilenet_v2.preprocess_input(image)
    elif "resnet" in model:
        image = tf.keras.applications.resnet50.preprocess_input(image)
    else:
        raise ValueError("Invalid model version. Choose 'v2-0.5', 'v2-1.0' or 'resnet50'.")
    image = image[None, ...]
    return image

# Helper function to extract labels from probability vector
def get_imagenet_label(probs, decode_predictions):
    return decode_predictions(probs, top=1)[0][0]


def create_adversarial_pattern(input_image, input_label, pretrained_model):
    loss_object = tf.keras.losses.CategoricalCrossentropy()
    with tf.GradientTape() as tape:
        tape.watch(input_image)
        prediction = pretrained_model(input_image)
        loss = loss_object(input_label, prediction)

    # Get the gradients of the loss w.r.t to the input image.
    gradient = tape.gradient(loss, input_image)
    # Get the sign of the gradients to create the perturbation
    signed_grad = tf.sign(gradient)
    return signed_grad


def display_images(
    pretrained_model, image, description, image_name, decode_predictions
):
    _, label, confidence = get_imagenet_label(
        pretrained_model.predict(image), decode_predictions
    )
    plt.figure()
    plt.imshow(image[0] * 0.5 + 0.5)
    plt.title(
        "{} \n {} : {:.2f}% Confidence".format(description, label, confidence * 100)
    )
    print("Adversarial example with {}, {}: {:.2f}% Confidence".format(description, label, confidence * 100))

    adversarial_example_path = "./images/" + image_name
    plt.savefig(adversarial_example_path)
    # plt.show()

    return adversarial_example_path

def transfering_attack(adverarial_example, model, decode_predictions):
    # Just use the image as the input, predict the label
    image_probs = model.predict(adverarial_example)
    _, image_class, class_confidence = get_imagenet_label(
        image_probs, decode_predictions
    )
    print("{} : {:.2f}% Confidence".format(image_class, class_confidence * 100))

def main():
    args = parse_args()
    image_name = args.image
    epsilon = args.epsilon
    model_version = args.model_version
    print_params = args.print_params
    transfer_model_version = args.transfer_model_version
    target_label = args.target_label

    if target_label is not None:
        if target_label < 0 or target_label > 999:
            raise ValueError("Target label must be between 0 and 999.")
        index = target_label
        print("Target label is set to:", index)

    if image_name == "labrador":
        image_path = "./images/YellowLabradorLooking.jpg"
        if target_label is None:
            index = labrador_retriever_index
    else:
        image_path = "./images/panda.jpg"
        if target_label is None:
            index = panda_index

    if epsilon > 1.0 or epsilon < 0.0:
        raise ValueError("Epsilon must be between 0 and 1.")

    if model_version == "v2-0.5":
        pretrained_model = tf.keras.applications.MobileNetV2(
            include_top=True, alpha=0.5, weights="imagenet"
        )
    elif model_version == "v2-1.0":
        pretrained_model = tf.keras.applications.MobileNetV2(
            include_top=True, alpha=1.0, weights="imagenet"
        )
    else:
        raise ValueError("Invalid model version. Choose 'v2-0.5', 'v2-1.0'.")

    mpl.rcParams["figure.figsize"] = (8, 8)
    mpl.rcParams["axes.grid"] = False

    if print_params:
        print("Model version:", model_version)
        print("Model params:", pretrained_model.count_params())

    pretrained_model.trainable = False

    # ImageNet labels
    decode_predictions = tf.keras.applications.mobilenet_v2.decode_predictions

    image = preprocess(image_path, model_version)
    image_probs = pretrained_model.predict(image)

    plt.figure()
    plt.imshow(image[0] * 0.5 + 0.5)  # To change [-1, 1] to [0,1]
    _, image_class, class_confidence = get_imagenet_label(
        image_probs, decode_predictions
    )
    plt.title("{} : {:.2f}% Confidence".format(image_class, class_confidence * 100))
    print("Original image {} : {:.2f}% Confidence".format(image_class, class_confidence * 100))
    # plt.savefig("original_image_{}_{}_{}_{:.2f}.jpg".format(image_name, model_version, image_class, class_confidence * 100))
    # plt.show()

    # Generate adversarial example
    label = tf.one_hot(index, image_probs.shape[-1])
    label = tf.reshape(label, (1, image_probs.shape[-1]))

    perturbations = create_adversarial_pattern(image, label, pretrained_model)

    adv_x = image + epsilon * perturbations
    # plt.imshow(epsilon * perturbations[0] * 0.5 + 0.5)
    # plt.title("Perturbation with epsilon = {:0.3f}".format(epsilon))
    
    adv_x = tf.clip_by_value(adv_x, -1, 1)
    adv_image_name = "adversarial_image_{}_{}_{:0.3f}.jpg".format(image_name, model_version, epsilon)
    adversarial_example_path = display_images(
        pretrained_model,
        adv_x,
        "epsilon = {:0.3f}".format(epsilon),
        adv_image_name,
        decode_predictions,
    )

    # Transfering attack
    if transfer_model_version is not None:
        if transfer_model_version == "v2-0.5":
            transfer_pretrained_model = tf.keras.applications.MobileNetV2(
                include_top=True, alpha=0.5, weights="imagenet"
            )
        elif transfer_model_version == "v2-1.0":
            transfer_pretrained_model = tf.keras.applications.MobileNetV2(
                include_top=True, alpha=1.0, weights="imagenet"
            )
        elif transfer_model_version == "resnet50":
            transfer_pretrained_model = tf.keras.applications.ResNet50(
                include_top=True, weights="imagenet"
            )
        else:
            raise ValueError("Invalid model version. Choose 'v2-0.5', 'v2-1.0' or 'resnet50'.")
        transfer_pretrained_model = tf.keras.applications.ResNet50(
            include_top=True, weights="imagenet"
        )
        transfer_pretrained_model.trainable = False
        decode_predictions = tf.keras.applications.resnet50.decode_predictions
        adversarial_example = preprocess(adversarial_example_path, transfer_model_version)
        transfering_attack(adversarial_example, transfer_pretrained_model, decode_predictions)


if __name__ == "__main__":
    main()

    
