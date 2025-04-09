import tensorflow as tf
import matplotlib as mpl
import matplotlib.pyplot as plt
import argparse

labrador_retriever_index = 208
panda_retriever_index = 388


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
        help="Version of the model to use, you can only type in v2-0.5 or v2-1.0",
        default="v2-1.0",
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
def preprocess(image):
    # image = tf.cast(image, tf.float32)
    image = tf.image.resize(image, (224, 224))
    image = tf.keras.applications.mobilenet_v2.preprocess_input(image)
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

    plt.savefig("./images/" + image_name)
    # plt.show()


def main():
    args = parse_args()
    image_name = args.image
    epsilon = args.epsilon
    model_version = args.model_version
    print_params = args.print_params

    if image_name == "":
        image_path = "./images/panda.jpg"
        index = panda_retriever_index
    elif image_name == "labrador":
        image_path = "./images/YellowLabradorLooking.jpg"
        index = labrador_retriever_index
    else:
        image_path = "./images/panda.jpg"
        index = panda_retriever_index

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
        raise ValueError("Invalid model version. Choose 'v2-0.5' or 'v2-1.0'.")

    mpl.rcParams["figure.figsize"] = (8, 8)
    mpl.rcParams["axes.grid"] = False

    if print_params:
        print("Model version:", model_version)
        print("Model params:", pretrained_model.count_params())

    pretrained_model.trainable = False

    # ImageNet labels
    decode_predictions = tf.keras.applications.mobilenet_v2.decode_predictions

    image_raw = tf.io.read_file(image_path)
    image = tf.image.decode_image(image_raw)

    image = preprocess(image)
    image_probs = pretrained_model.predict(image)

    plt.figure()
    plt.imshow(image[0] * 0.5 + 0.5)  # To change [-1, 1] to [0,1]
    _, image_class, class_confidence = get_imagenet_label(
        image_probs, decode_predictions
    )
    plt.title("{} : {:.2f}% Confidence".format(image_class, class_confidence * 100))
    # plt.savefig("original_image_{}_{}_{}_{:.2f}.jpg".format(image_name, model_version, image_class, class_confidence * 100))
    # plt.show()

    # Get the input label of the image.
    label = tf.one_hot(index, image_probs.shape[-1])
    label = tf.reshape(label, (1, image_probs.shape[-1]))

    perturbations = create_adversarial_pattern(image, label, pretrained_model)

    adv_x = image + epsilon * perturbations
    # plt.imshow(epsilon * perturbations[0] * 0.5 + 0.5)
    # plt.title("Perturbation with epsilon = {:0.3f}".format(epsilon))
    
    adv_x = tf.clip_by_value(adv_x, -1, 1)
    adv_image_name = "adversarial_image_{}_{}_{:0.3f}.jpg".format(image_name, model_version, epsilon)
    display_images(
        pretrained_model,
        adv_x,
        "Epsilon = {:0.3f}".format(epsilon),
        adv_image_name,
        decode_predictions,
    )


if __name__ == "__main__":
    main()
