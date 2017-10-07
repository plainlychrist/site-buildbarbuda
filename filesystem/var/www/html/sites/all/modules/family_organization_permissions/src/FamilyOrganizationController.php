<?php

namespace Drupal\family_organization_permissions;

use Drupal\Core\Access\AccessResult;
use Drupal\Core\Entity\Controller\EntityController;
use Drupal\Core\Link;
use Drupal\Core\Routing\RouteMatchInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\group\Entity\Group;

/**
 * Provides add-page for family and organization entities.
 *
 * Analog is addPage($entity_type_id) in parent class.
 */
class FamilyOrganizationController extends EntityController {

 /**
   * Displays add links for the available bundles.
   *
   * Redirects to the add form if there's only one bundle available.
   *
   * @param string $entity_type_id
   *   The entity type ID.
   *
   * @return \Symfony\Component\HttpFoundation\RedirectResponse|array
   *   If there's only one available bundle, a redirect response.
   *   Otherwise, a render array with the add links for each bundle.
   */
  public function addMediaPage(Group $group) {
    $famorgtype = _family_organization_permissions_get_if_family_or_org_for_group($group);
    if (is_null($famorgtype)) {
      throw new \Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException();
    }

    $entity_type_id = 'media';
    $entity_type = $this->entityTypeManager->getDefinition($entity_type_id);
    $bundles = $this->entityTypeBundleInfo->getBundleInfo($entity_type_id);
    $bundle_key = $entity_type->getKey('bundle');
    $bundle_entity_type_id = $entity_type->getBundleEntityType();
    $build = [
      '#theme' => 'entity_add_list',
      '#bundles' => [],
    ];
    if ($bundle_entity_type_id) {
      $bundle_argument = $bundle_entity_type_id;
      $bundle_entity_type = $this->entityTypeManager->getDefinition($bundle_entity_type_id);
      $bundle_entity_type_label = $bundle_entity_type->getLowercaseLabel();
      $build['#cache']['tags'] = $bundle_entity_type->getListCacheTags();

      // Build the message shown when there are no bundles.
      $link_text = $this->t('Add a new @entity_type.', ['@entity_type' => $bundle_entity_type_label]);
      $link_route_name = 'entity.' . $bundle_entity_type->id() . '.add_form';
      $build['#add_bundle_message'] = $this->t('There is no @entity_type yet. @add_link', [
        '@entity_type' => $bundle_entity_type_label,
        '@add_link' => Link::createFromRoute($link_text, $link_route_name)->toString(),
      ]);
      // Filter out the bundles the user doesn't have access to. Also filter bundles that do not
      // have the 'Allowed Families and Organizations' field (not present means it is a public bundle).
      $access_control_handler = $this->entityTypeManager->getAccessControlHandler($entity_type_id);
      $entity_field_manager = \Drupal::service('entity_field.manager');
      $bundles_with_private_field = $entity_field_manager->getFieldMap()[$entity_type_id]['field_allowed_families_and_organ']['bundles'];
      foreach ($bundles as $bundle_name => $bundle_info) {
        $access = $access_control_handler->createAccess($bundle_name, NULL, [], TRUE);
        if (!$access->isAllowed()) {
          unset($bundles[$bundle_name]);
        } elseif (!in_array($bundle_name, $bundles_with_private_field)) {
          unset($bundles[$bundle_name]);
        }
        $this->renderer->addCacheableDependency($build, $access);
      }
      // Add descriptions from the bundle entities.
      $bundles = $this->loadBundleDescriptions($bundles, $bundle_entity_type);
    }
    else {
      $bundle_argument = $bundle_key;
    }

    $form_route_name = 'entity.' . $entity_type_id . '.' . $famorgtype . '.add_form';
    // Redirect if there's only one bundle available.
    if (count($bundles) == 1) {
      $bundle_names = array_keys($bundles);
      $bundle_name = reset($bundle_names);
      return $this->redirect($form_route_name, [$bundle_argument => $bundle_name]);
    }
    // Prepare the #bundles array for the template.
    foreach ($bundles as $bundle_name => $bundle_info) {
      $build['#bundles'][$bundle_name] = [
        'label' => $bundle_info['label'],
        'description' => isset($bundle_info['description']) ? $bundle_info['description'] : '',
        'add_link' => Link::createFromRoute($bundle_info['label'], $form_route_name, [$bundle_argument => $bundle_name, 'group' => $group->id()]),
      ];
    }

    return $build;
  }

  /**
   * Provides a generic add title callback for an entity type.
   *
   * @param string $entity_type_id
   *   The entity type ID.
   *
   * @return string
   *    The title for the entity add page.
   */
  public function addFamilyMediaTitle(Group $group) {
    $entity_type_id = 'media';
    $entity_type = $this->entityTypeManager->getDefinition($entity_type_id);
    return $this->t('Add @entity-type for the @group family', ['@entity-type' => $entity_type->getLowercaseLabel(), '@group' => $group->label()]);
  }

  /**
   * Provides a generic add title callback for an entity type.
   *
   * @param string $entity_type_id
   *   The entity type ID.
   *
   * @return string
   *    The title for the entity add page.
   */
  public function addOrganizationMediaTitle(Group $group) {
    $entity_type_id = 'media';
    $entity_type = $this->entityTypeManager->getDefinition($entity_type_id);
    return $this->t('Add @entity-type for the @group organization', ['@entity-type' => $entity_type->getLowercaseLabel(), '@group' => $group->label()]);
  }

  /**
   * Provides a generic add title callback for entities with bundles.
   *
   * @param \Drupal\Core\Routing\RouteMatchInterface $route_match
   *   The route match.
   * @param string $entity_type_id
   *   The entity type ID.
   * @param string $bundle_parameter
   *   The name of the route parameter that holds the bundle.
   *
   * @return string
   *    The title for the entity add page, if the bundle was found.
   */
  public function addFamilyMediaBundleTitle(RouteMatchInterface $route_match, Group $group, $bundle_parameter) {
    $entity_type_id = 'media';
    $bundles = $this->entityTypeBundleInfo->getBundleInfo($entity_type_id);
    // If the entity has bundle entities, the parameter might have been upcasted
    // so fetch the raw parameter.
    $bundle = $route_match->getRawParameter($bundle_parameter);
    if ((count($bundles) > 1) && isset($bundles[$bundle])) {
      return $this->t('Add @bundle for the @group family', ['@bundle' => $bundles[$bundle]['label'], '@group' => $group->label()]);
    }
    // If the entity supports bundles generally, but only has a single bundle,
    // the bundle is probably something like 'Default' so that it preferable to
    // use the entity type label.
    else {
      return $this->addTitle($entity_type_id);
    }
  }

  /**
   * Provides a generic add title callback for entities with bundles.
   *
   * @param \Drupal\Core\Routing\RouteMatchInterface $route_match
   *   The route match.
   * @param string $entity_type_id
   *   The entity type ID.
   * @param string $bundle_parameter
   *   The name of the route parameter that holds the bundle.
   *
   * @return string
   *    The title for the entity add page, if the bundle was found.
   */
  public function addOrganizationMediaBundleTitle(RouteMatchInterface $route_match, Group $group, $bundle_parameter) {
    $entity_type_id = 'media';
    $bundles = $this->entityTypeBundleInfo->getBundleInfo($entity_type_id);
    // If the entity has bundle entities, the parameter might have been upcasted
    // so fetch the raw parameter.
    $bundle = $route_match->getRawParameter($bundle_parameter);
    if ((count($bundles) > 1) && isset($bundles[$bundle])) {
      return $this->t('Add @bundle for the @group organization', ['@bundle' => $bundles[$bundle]['label'], '@group' => $group->label()]);
    }
    // If the entity supports bundles generally, but only has a single bundle,
    // the bundle is probably something like 'Default' so that it preferable to
    // use the entity type label.
    else {
      return $this->addTitle($entity_type_id);
    }
  }

  /**
   * Checks access for a specific request.
   *
   * @param \Drupal\Core\Session\AccountInterface $account
   *   Run access checks for this account.
   */
  public function accessMedia(AccountInterface $account, Group $group) {
    // Check permissions and combine that with any custom access checking needed. Pass forward
    // parameters from the route and/or request as needed.
    if ($account->hasPermission('administer media')) {
      return AccessResult::allowed()->cachePerPermissions();
    }
    return AccessResult::allowedIf(_family_organization_permissions_access('view', $group, $account))->cachePerPermissions()->cachePerUser();
  }

}
